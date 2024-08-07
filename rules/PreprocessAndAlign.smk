rule CopyFastq:
    """
    Useful for when a single sample is spread across multiple fastq, or when the original fastq is in long term storage cds
    """
    input:
        R1 = lambda wildcards: samples.loc[wildcards.sample]['R1'],
        R2 = lambda wildcards: samples.loc[wildcards.sample]['R2'],
    output:
        R1 = temp("Fastq/{sample}.R1.fastq.gz"),
        R2 = temp("Fastq/{sample}.R2.fastq.gz"),
    shell:
        """
        cat {input.R1} > {output.R1}
        cat {input.R2} > {output.R2}
        """

rule fastp:
    """
    clips adapters, can handle UMIs
    """
    input:
        R1 = "Fastq/{sample}.R1.fastq.gz",
        R2 = "Fastq/{sample}.R2.fastq.gz",
    output:
        R1 = "FastqFastp/{sample}.R1.fastq.gz",
        R2 = "FastqFastp/{sample}.R2.fastq.gz",
        html = "FastqFastp/{sample}.fastp.html",
        json = "FastqFastp/{sample}.fastp.json"
    params:
    resources:
        mem_mb = GetMemForSuccessiveAttempts(8000, 24000)
    log:
        "logs/fastp/{sample}.log"
    conda:
        "../envs/fastp.yml"
    shell:
        """
        fastp -i {input.R1} -I {input.R2}  -o {output.R1} -O {output.R2} --html {output.html} --json {output.json} &> {log}
        """

rule STAR_Align: #This code is intended for paired end reads which is why there are R1/R2 ... going to make one for single end
    input:
        index = lambda wildcards: config['GenomesPrefix'] + samples.loc[wildcards.sample]['STARGenomeName'] + "/STARIndex",
        R1 = "FastqFastp/{sample}.R1.fastq.gz",
        R2 = "FastqFastp/{sample}.R2.fastq.gz"
    output:
        outdir = directory("Alignments/STAR_Align/{sample}"),
        bam = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",
        align_log = "Alignments/STAR_Align/{sample}/Log.final.out"
    threads: 8
    log: "logs/STAR_Align/{sample}.log"
    params:
        GetSTARIndexDir = "/project2/yangili1/bjf79/ChromatinSplicingQTLs/code/ReferenceGenome/STARIndex/",
        readMapNumber = -1, #number of reads to map from the beginning of the file, -1 means map all reads 
        ENCODE_params = "--outFilterType BySJout --outFilterMultimapNmax 20  --alignSJoverhangMin 8 --alignSJDBoverhangMin 1 --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04 --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000",
        # --outFilterType BySJout reduces the number of ”spurious” junctions; 
        #--outFilterMultimapNmax 20max number of multiple alignments allowed for a read: if exceeded, the read is considered unmapped 
    resources:
        tasks = 9,
        mem_mb = 48000,
        # N = 1
    shell:
        """
        STAR --readMapNumber {params.readMapNumber} --outFileNamePrefix {output.outdir}/ --genomeDir {input.index}/ --readFilesIn {input.R1} {input.R2}  --outSAMtype BAM SortedByCoordinate --readFilesCommand zcat --runThreadN {threads} --outSAMmultNmax 1 --limitBAMsortRAM 8000000000 {params.ENCODE_params} --outSAMstrandField intronMotif  &> {log}
        """

#--genomeDir specifies path to the genome directory where genome indices where generated
# --outSAMtype BAM SortedByCoordinate output sorted by coordinate Aligned.sortedByCoord.out.bam file, similar to samtools sort command.
# --readFilesCommand ... since input files are compressed .gz 

rule indexBam:
    input:
        bam = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",
    log:
        "logs/indexBam/{sample}.log"
    output:
        bai = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam.bai",
    shell: "samtools index {input} &> {log}"


rule idxstats:
    input:
        bam = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",
        bai = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam.bai",
    output:
        "idxstats/{sample}.idxstats.txt"
    shell:
        """
        samtools idxstats {input.bam} > {output}
        """
