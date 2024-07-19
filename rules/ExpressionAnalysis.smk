
rule featurecounts:
    input:
        bam = ExpandAllSamplesInFormatStringFromGenomeNameAndStrandWildcards("Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam"),
        bai = ExpandAllSamplesInFormatStringFromGenomeNameAndStrandWildcards("Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam.bai"),
        gtf = config['GenomesPrefix'] + config['GenomeName']+ "/Reference.basic.gtf",
    output:
        counts = "featureCounts/" + config['GenomeName'] + "/{Strandedness}.Counts.txt",
        summary = "featureCounts/" + config['GenomeName'] + "/{Strandedness}.Counts.txt.summary",
    threads:
        8
    resources:
        mem_mb = 12000,
        tasks = 9,
    log:
        "logs/featureCounts/" + config['GenomeName'] + ".{Strandedness}.log"
    params:
        strand = lambda wildcards: {'FR':'-s 1', 'U':'-s 0', 'RF':'-s 2'}[wildcards.Strandedness],
        extra = ""
    shell:
        """
        featureCounts -p {params.strand} {params.extra} -T {threads} --ignoreDup --primary -a {input.gtf} -o {output.counts} {input.bam} &> {log}
        """

use rule featurecounts as featurecounts_allUnstranded with:
    input:
        bam = ExpandAllSamplesInFormatStringFromGenomeNameWildcard("Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam"),
        bai = ExpandAllSamplesInFormatStringFromGenomeNameWildcard("Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam.bai"),
        gtf = config['GenomesPrefix'] + config['GenomeName'] + "/Reference.basic.gtf",
    output:
        counts = "featureCounts/" + config['GenomeName'] + "/AllSamplesUnstrandedCounting.Counts.txt",
        summary = "featureCounts/" + config['GenomeName'] + "/AllSamplesUnstrandedCounting.Counts.txt.summary",
    threads:
        8
    resources:
        mem_mb = 12000,
        tasks = 9,
    log:
        "logs/featureCounts/" + config['GenomeName'] + ".AllUnstranded.log"
    params:
        strand = '-s 0',
        extra = ""

# rule GetGeneNames_bioMart:
