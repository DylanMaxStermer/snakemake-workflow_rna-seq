rule DownloadFastaAndGtf:
    output:
        fa = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa",
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.gtf"
        # fa = "{{GenomesPrefix}}{GenomeName}/Reference.fa",
        # gtf = "{{GenomesPrefix}}{GenomeName}/Reference.gtf"

    params: # trying to make it so I can just state the species in the config file that way the pipeline works for multiple species
        fa_link = lambda wildcards: STAR_genomes.loc[config['GenomeName'], 'FastaLink'],
        gtf_link = lambda wildcards: STAR_genomes.loc[config['GenomeName'], 'GtfLink']

    shell:
        """
        wget -O- {params.fa_link} | zcat > {output.fa}
        wget -O- {params.gtf_link} | zcat > {output.gtf}
        """

rule GetBasicGtf:
    """
    Some analysis are better done with just 'basic' tagged transcripts,
    transcript structures thought to encode functional transcripts. This shell
    command works with Gencode formatted gtf, haven't looked at Ensembl gtfs
    """
    input:
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.gtf"
    output:
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.basic.gtf"
    shell:
        """
        awk '/^##/ || /tag "basic"/ || $3=="gene"' {input.gtf} > {output.gtf}
        """


rule indexHg38Ref:
    input:
        fa = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa",
    output:
        fai = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa.fai",
    shell:
        """
        samtools faidx {input.fa}
        """

rule gtf_to_bed12:
    """
    This shell command works with Gencode formatted gtf, haven't looked at
    Ensembl gtfs
    """
    input:
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.gtf"
    output:
        bed = temp(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.bed.gz"),
        tbi = temp(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.bed.gz.tbi")
    conda:
        "../envs/bedparse.yml"
    shell:
      """
        bedparse gtf2bed {input.gtf} --extraFields gene_id,transcript_id,gene_type,gene_name,transcript_type,transcript_support_level,tag,transcript_name | awk -F'\\t' -v OFS='\\t' '{{$4=$NF; print $0}}' | bedtools sort -i - | bgzip /dev/stdin -c > {output.bed}
        tabix -p bed {output.bed}
      """

rule colorize_gtfbed:
    """
    Only tested on human Gencode v44
    """
    input:
        bed = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.bed.gz",
    output:
        bed = temp(config['GenomesPrefix'] + config['GenomeName'] + "/Reference.colored.bed"),
        colorkey = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.colored.ColorsKey.png"
    conda:
        "../envs/r_2.yml"
    log:
        "logs/colorize_gtfbed/" + config['GenomeName'] + ".log"
    shell:
        """
        Rscript ../scripts/ColorTranscriptsInGtfBed.R {input.bed} {output.bed} {output.colorkey} &> {log}
        """
        
rule index_colored_bed12:
    input:
        bed = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.colored.bed",
    output:
        bed = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.Transcripts.colored.bed.gz",
        tbi = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.Transcripts.colored.bed.gz.tbi"
    shell:
        """
        bedtools sort -i {input.bed} | bgzip /dev/stdin -c > {output.bed}
        tabix -p bed {output.bed}
        """

rule STAR_make_index:
    """
    did not work on bigmem2. Never figured out why (the log file didn't
    indicate anything). Ran on login node with success.
    """
    input:
        fa = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa",
        fai = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.fa.fai",
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.gtf"
    output:
        index = directory(config['GenomesPrefix'] + config['GenomeName'] + "/STARIndex")
    log:
        "logs/STAR_make_index/" + config['GenomeName'] + ".log"
    params:
    threads: 4
    resources:
        mem = "52000",
        # partition = "bigmem2",
        ntasks = 5
    shell:
        """
        mkdir -p {output.index}
        STAR --runMode genomeGenerate --genomeSAsparseD 2 --runThreadN {threads} --genomeDir {output.index}/ --sjdbGTFfile {input.gtf} --genomeFastaFiles {input.fa} &> {log}
        """

rule Gather_STAR_Indexes:
    input: #not sure how the GenomeName thing would work here 
        expand(config['GenomesPrefix'] + config['GenomeName'] + "/STARIndex", GenomeName = STAR_genomes.index)
