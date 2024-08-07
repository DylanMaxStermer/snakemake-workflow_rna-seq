# The main entry point of your workflow.
# After configuring, running snakemake -n in a clone of this repository should successfully execute a dry-run of the workflow.
# Config file should have unique sample names for each sample. Rows with the
# same samples name will be merged (eg, for combining the same sample
# sequencing across multiple lanes with multiple sets of fastq)

#This sets the output direcotory to be here essentially. 
workdir: "Results"

configfile: "../config/config.yaml"

include: "rules/common.smk"

wildcard_constraints:
    GenomeName = "|".join(STAR_genomes.index),
    sample = "|".join(samples.index),
    Strandedness = "|".join(["U", "FR", "RF"])
localrules: DownloadFastaAndGtf, CopyFastq, MultiQC

include: "rules/PreprocessAndAlign.smk"
include: "rules/IndexGenome.smk"
include: "rules/SplicingAnalysis.smk"
include: "rules/ExpressionAnalysis.smk"
include: "rules/QC.smk"
include: "rules/MakeBigwigs.smk"
#include: "rules/spliceQ.smk"


rule all:
    input:
        expand("Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",sample=samples.index),
        expand("SplicingAnalysis/juncfiles/{sample}.junccounts.tsv.gz", sample=samples.index),
        expand("FastqFastp/{sample}.fastp.html", sample=samples.index),
        "../output/QC/ReadCountsPerSamples.tsv",
        expand("bigwigs/unstranded/{sample}.bw", sample=samples.index),
        "SplicingAnalysis/ObservedJuncsAnnotations/" + config['GenomeName'] + ".uniq.annotated.tsv.gz",
        "Multiqc",
        "featureCounts/" + config['GenomeName'] + "/AllSamplesUnstrandedCounting.Counts.txt",
        config['GenomesPrefix'] + config['GenomeName'] + "/Reference.Transcripts.colored.bed.gz"
        #expand("spliceQ/{sample}.png", sample=samples.index)
       # expand("featureCounts/GRCh38_GencodeRelease44Comprehensive/{Strandedness}.Counts.txt", Strandedness=samples['Strandedness'].unique())

   