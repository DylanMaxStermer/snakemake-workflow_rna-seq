
# THIS SCRIPT CURRENTLY DOESN'T WORK NEED TO KEEP WORKING ON IT

rule Calculate_Intron_Excision_Ratio:
    """
    Calculating intron persistence
    """
    input:
        bam = "Alignments/STAR_Align/{sample}/Aligned.sortedByCoord.out.bam",
        gtf = "GRCh38_GencodeRelease44Comprehensive/Reference.basic.gtf"
    output:
        png = "spliceQ/{sample}.png"
    log:
        "logs/spliceQ/{sample}.log"
    shell:
        """
        SPLICE-q.py -b {input.bam} -g {input.gtf} --IERatio -o {output.png} &> {log}
        """



