$if(citations)$
$if(csl)$

#set bibliography(style: "$csl$")
$elseif(bibliographystyle)$

#set bibliography(style: "$bibliographystyle$")
$endif$
$if(bibliography)$
$-- Suppress bibliography display when citation-location: margin (consistent with HTML behavior)
$-- Full citations appear in margins; bibliography is loaded but not displayed
$if(suppress-bibliography)$
#show bibliography: none
$endif$

// Local patch: suppress Typst's automatic "Bibliography" heading. Each
// poster template already places its own numbered "References" heading
// (see the `#### References` / `::: {#refs} :::` div in poster.qmd)
// immediately before this call, so the built-in title would otherwise
// duplicate it -- see the note in README.md.
//
// Local patch: shrink the reference-list text below the poster's body
// size. Citations are reference material, not primary content, and a
// smaller size is conventional on printed posters; nothing follows the
// bibliography in the document flow, so this size change doesn't need
// to be reset afterward.
#set text(size: 16pt)
#bibliography(($for(bibliography)$"$bibliography$"$sep$,$endfor$), title: none)
$endif$
$endif$
