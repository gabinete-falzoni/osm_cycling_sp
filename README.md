Scripts to download the city of São Paulo's cycling infrastructure from OpenStreetMap.

The main script is faster and uses only native R packages. It (a) downloads the OSM map directly into RAM, (b) extracts the road infrastructure with the city's polygon and (c) categorizes the cycling infrastructure according to its local type.

Scripts in the 'slower_version' folder are, well, slower and require osmosis installed in the system. They also download the OSM map into disk instead of using only RAM.
