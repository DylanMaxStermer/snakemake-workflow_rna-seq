rule ExtractJuncs:
    input:
        bam = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",
        bai = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam.bai",
    output:
        "SplicingAnalysis/juncfiles/{sample}.junc",
    params:
        strand = "0"
    conda:
        "../envs/regtools.yml"
    log:
        "logs/ExtractJuncs/{sample}.log"
    shell:
        """
        (regtools junctions extract -m 20 -s {params.strand} {input.bam} > {output}) &> {log}
        """


rule annotate_juncfiles:
    input:
        fa = FillGenomeNameInFormattedString(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa"),
        fai = FillGenomeNameInFormattedString(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa.fai"),
        gtf = FillGenomeNameInFormattedString(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.gtf"),
        juncs = "SplicingAnalysis/juncfiles/{sample}.junc",
    output:
        counts = "SplicingAnalysis/juncfiles/{sample}.junccounts.tsv.gz"
    log:
        "logs/annotate_juncfiles/{sample}.log"
    conda:
        "../envs/regtools.yml"
    shell:
        """
        (regtools junctions annotate {input.juncs} {input.fa} {input.gtf} | awk -F'\\t' -v OFS='\\t' 'NR>1 {{$4=$1"_"$2"_"$3"_"$6; print $4, $5}}' | gzip - > {output.counts} ) &> {log}
        """


rule ConcatJuncFilesAndKeepUniq:
    input:
        ExpandAllSamplesInFormatStringFromGenomeNameWildcard("SplicingAnalysis/juncfiles/{sample}.junc"),
    output:
        "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.junc"
    log:
        "logs/ConcatJuncFilesAndKeepUniq/" + config['GenomeName'] + ".log"
    resources:
        mem_mb = GetMemForSuccessiveAttempts(24000, 48000)
    shell:
        """
        (awk '{{ split($11, blockSizes, ","); JuncStart=$2+blockSizes[1]; JuncEnd=$3-blockSizes[2]; print $0, JuncStart, JuncEnd }}' {input} | sort -k1,1 -k6,6 -k13,13n -k14,14n -u | cut -f 1-12 | bedtools sort -i - >> {output}) &> {log}
        """

rule AnnotateConcatedUniqJuncFile_basic:
    input:
        junc = "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.junc",
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.basic.gtf",
        fa = config['GenomesPrefix']  + config['GenomeName'] + "/Reference.fa"
    output:
        "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.annotated.tsv.gz"
    log:
        "logs/AnnotateConcatedUniqJuncFile_hg38Basic." + config['GenomeName'] + ".log"
    conda:
        "../envs/regtools.yml"
    shell:
        """
        (regtools junctions annotate {input.junc} {input.fa} {input.gtf} | gzip - > {output} ) &> {log}
        """

rule make_leafcutter_juncfile:
    input:
        ExpandAllSamplesInFormatStringFromGenomeNameWildcard("SplicingAnalysis/juncfiles/{sample}.junc"),
    output:
        "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncfilelist.txt"
    params:
        SamplesToRemove = ""
    run:
        import os
        if params.SamplesToRemove:
            SamplesToRemove = open(params.SamplesToRemove, 'r').read().split('\n')
        else:
            SamplesToRemove=[]
        with open(output[0], "w") as out:
            for filepath in input:
                samplename = os.path.basename(filepath).split(".junc")[0]
                if samplename not in  SamplesToRemove:
                    out.write(filepath + '\n')

rule leafcutter_cluster:
    input:
        juncs = ExpandAllSamplesInFormatStringFromGenomeNameWildcard("SplicingAnalysis/juncfiles/{sample}.junc"),
        juncfile_list = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncfilelist.txt"
    output:
        outdir = directory("SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/clustering/"),
        counts = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/clustering/leafcutter_perind.counts.gz",
        numers = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/clustering/leafcutter_perind_numers.counts.gz"
    shadow: "shallow"
    resources:
        mem_mb = GetMemForSuccessiveAttempts(24000, 48000)
    log:
        "logs/leafcutter_cluster/" + config['GenomeName'] + ".log"
    params:
        "-p 0.0001"
    shell:
        """
        python scripts/leafcutter/clustering/leafcutter_cluster_regtools.py -j {input.juncfile_list} {params} -r {output.outdir} &> {log}
        """

rule leafcutter_to_PSI:
    input:
        numers = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "clustering/leafcutter_perind_numers.counts.gz"
    output:
        juncs = temp("SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/JuncCounts.bed"),
        PSIByMax = temp("SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/PSI.bed"),
        PSI = temp("SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/PSI_ByMax.bed"),
    log:
        "logs/leafcutter_to_PSI/" + config['GenomeName'] + ".log"
    resources:
        mem_mb = GetMemForSuccessiveAttempts(24000, 54000)
    conda:
        "../envs/r_2.yml"
    shell:
        """
        Rscript scripts/leafcutter_to_PSI.R {input.numers} {output.PSI} {output.PSIByMax} {output.juncs} &> {log}
        """

rule bgzip_PSI_bed:
    input:
        bed = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/{Metric}.bed",
    output:
        bed = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/{Metric}.sorted.bed.gz",
        tbi  = "SplicingAnalysis/leafcutter/" + config['GenomeName'] + "/juncTableBeds/{Metric}.sorted.bed.gz.tbi",
    log:
        "logs/bgzip_PSI_bed/" + config['GenomeName'] + "/{Metric}.log"
    resources:
        mem_mb = GetMemForSuccessiveAttempts(24000, 54000)
    shell:
        """
        (bedtools sort -header -i {input.bed} | bgzip /dev/stdin -c > {output.bed}) &> {log}
        (tabix -p bed {output.bed}) &>> {log}
        """

rule Get5ssSeqs:
    """
    Filtered out entries with N in sequence
    """
    input:
        basic = "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.annotated.tsv.gz",
        fa = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa",
    output:
        "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.annotated.DonorSeq.tsv"
    shell:
        """
        zcat {input.basic} | awk -v OFS='\\t' -F'\\t' 'NR>1 {{print $1, $2, $3, $1"_"$2"_"$3"_"$6, ".", $6}}' | sort -u | awk -v OFS='\\t' -F'\\t'  '$6=="+" {{$2=$2-4; $3=$2+11; print $0}} $6=="-" {{$3=$3+3; $2=$3-11; print $0}}' | bedtools getfasta -tab -bed - -s -name -fi {input.fa} | grep -v 'N' > {output}
        """
