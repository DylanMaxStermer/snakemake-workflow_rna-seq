
# THIS SCRIPT CURRENTLY DOESN'T WORK NEED TO KEEP WORKING ON IT

rule make_tracks_ini: 
    """"
    make the tracks.ini needed for the next code 
    """"
    input:
        bw = "bigwigs/unstranded/{sample}.bw", 
        bed = config['GenomesPrefix'] + "{GenomeName}/Reference.bed.gz"
    output:
        ini = "Results/pyGenome/tracks.ini"
    shell:
        """"
        make_tracks_file --trackFiles <input.bw> <input.bed> etc. -o <output.ini>
        """"



rule pygenome_track:
    """
    Generate pyGenomeTracks visualization for a given region and set of tracks.
    """
    input:
        tracks= "Results/pyGenome/tracks.ini",
        regions= "pyGenomeTracks.tsv"
    output:
        png=temp("{region}.png")
    shell:
        """
        region=$(awk 'NR=={{wildcards.line_num}} {{print $2}}' {input.regions})
        name=$(awk 'NR=={{wildcards.line_num}} {{print $1}}' {input.regions})
        pyGenomeTracks --tracks {input.tracks} --region $region -o {output.png}
        """
