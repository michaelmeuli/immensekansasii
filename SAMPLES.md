# Mkan329 samples report

Generated 2026-10-05 by `scripts/mkan329_samples_report.py` from the per-sample
summary tables in `/shares/sander.imm.uzh/MM/kansasii/runs/mkan329/assembly/results/` and `data/imm/screening_map_link.csv`. Regenerate it after
every run or delivery; do not edit by hand.

## Coverage

- Screening map: 183 isolates (NR 1-183); **131 have results** (123 clinical isolates + 8 reference strains).
- Without results (52): NR 100, 108, 134-183 (not delivered yet, or no complete read pair).

## Species (GTDB-Tk, clinical isolates)

| Species | Isolates |
|---|---|
| M. kansasii | 84 |
| M. persicum | 23 |
| M. pseudokansasii | 13 |
| M. attenuatum | 2 |
| M. innocens | 1 |
| **Total** | **123** |

## Reference strains (controls)

| NR | Sample | Expected (screening map) | GTDB-Tk | ANI | Result |
|---|---|---|---|---|---|
| 126 | Mkan329-126 | M. tuberculosis H37Rv (ATCC 27294) | M. tuberculosis | 99.99 | match |
| 127 | Mkan329-127 | M. avium (ATCC 19421) | M. avium | 99.99 | match |
| 128 | Mkan329-128 | M. kansasii (ATCC 12478) | M. kansasii | 99.99 | match |
| 129 | Mkan329-129 | M. abscessus (ATCC 19977) | M. abscessus | 100.0 | match |
| 130 | Mkan329-130 | M. xenopi (ATCC 19970) | M. xenopi | 99.79 | match |
| 131 | Mkan329-131 | M. ulcerans (ATCC 19423) | M. marinum | 98.28 | match (ulcerans is marinum in GTDB) |
| 132 | Mkan329-132 | M. persicum (DSM 104278) | M. persicum | 99.97 | match |
| 133 | Mkan329-133 | M. pseudokansasii (DSM 107152) | M. pseudokansasii | 99.99 | match |

## Isolates to review

Heuristic flags of this report (thresholds below), not the pipeline QC.

| NR | Sample | Species (GTDB) | Flags | CheckM contam. % | MetaPhlAn4 (purity %) | Length Mb | Contigs |
|---|---|---|---|---|---|---|---|
| 8 | Mkan329-008 | M. innocens | MetaPhlAn differs | 0.53 | Mycobacterium kansasii (100.0) | 6.06 | 517 |
| 10 | Mkan329-010 | M. persicum | contamination, weak GTDB match, fragmented | 7.67 | Mycobacterium persicum (99.9) | 6.44 | 4665 |
| 21 | Mkan329-021 | M. kansasii | contamination | 7.76 | Mycobacterium kansasii (100.0) | 6.45 | 306 |
| 28 | Mkan329-028 | M. pseudokansasii | low purity | 3.25 | Mycobacterium pseudokansasii (85.7) | 6.56 | 413 |
| 35 | Mkan329-035 | M. kansasii | contamination, low purity, MetaPhlAn differs, genome size, fragmented | 113.37 | Mycobacterium ostraviense (68.5) | 13.05 | 1712 |
| 46 | Mkan329-046 | M. persicum | low purity | 0.68 | Mycobacterium persicum (94.3) | 6.16 | 229 |
| 55 | Mkan329-055 | M. persicum | fragmented | 2.47 | Mycobacterium persicum (100.0) | 5.89 | 1904 |
| 106 | Mkan329-106 | M. kansasii | contamination, fragmented | 20.44 | Mycobacterium kansasii (100.0) | 7.40 | 909 |
| 113 | Mkan329-113 | M. persicum | contamination, low purity, weak GTDB match, genome size, fragmented, low depth | 61.40 | Mycobacterium persicum (72.0) | 10.98 | 7473 |

Thresholds: CheckM contamination > 5 %, MetaPhlAn4 purity < 95 %, MetaPhlAn4 species differs from GTDB, GTDB alignment fraction < 0.9 or ANI < 98, kansasii-complex genome outside 5.5-7.5 Mb, more than 600 contigs, mean depth < 50x.

## All samples

| NR | Sample | TNR | Species (GTDB) | ANI | AF | MetaPhlAn4 | MLST ST | Length Mb | Contigs | N50 kb | Depth | CheckM compl./contam. | Flags |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Mkan329-001 | 2026500246 | M. kansasii | 99.36 | 0.977 | M. kansasii | 38 | 6.34 | 219 | 170 | 143 | 100.00/0.15 |  |
| 2 | Mkan329-002 | 2026500191 | M. persicum | 99.81 | 0.972 | M. persicum | 418 | 6.29 | 223 | 128 | 148 | 99.55/0.68 |  |
| 3 | Mkan329-003 | 2026500147 | M. kansasii | 99.44 | 0.957 | M. kansasii | 38 | 6.51 | 256 | 146 | 161 | 100.00/0.15 |  |
| 4 | Mkan329-004 | 2026500126 | M. pseudokansasii | 99.85 | 0.975 | M. pseudokansasii | 222 | 6.30 | 304 | 96 | 158 | 99.55/0.00 |  |
| 5 | Mkan329-005 | 2026333889 | M. kansasii | 99.91 | 0.979 | M. kansasii | 38 | 6.45 | 206 | 148 | 157 | 100.00/0.15 |  |
| 6 | Mkan329-006 | 2026333587 | M. kansasii | 99.37 | 0.969 | M. kansasii | - | 6.39 | 249 | 172 | 181 | 100.00/0.15 |  |
| 7 | Mkan329-007 | 2026333056 | M. pseudokansasii | 99.86 | 0.979 | M. pseudokansasii | 222 | 6.16 | 256 | 104 | 161 | 99.55/0.00 |  |
| 8 | Mkan329-008 | 2025500758 | M. innocens | 99.64 | 0.966 | M. kansasii | - | 6.06 | 517 | 53 | 135 | 100.00/0.53 | MetaPhlAn differs |
| 9 | Mkan329-009 | 2025500739 | M. persicum | 99.76 | 0.965 | M. persicum | - | 6.27 | 195 | 157 | 170 | 99.55/0.68 |  |
| 10 | Mkan329-010 | 2025500696 | M. persicum | 99.7 | 0.888 | M. persicum | 418 | 6.44 | 4665 | 3 | 146 | 93.71/7.67 | contamination, weak GTDB match, fragmented |
| 11 | Mkan329-011 | 2025500620 | M. kansasii | 100.0 | 1.0 | M. kansasii | 106 | 6.48 | 249 | 192 | 177 | 100.00/0.15 |  |
| 12 | Mkan329-012 | 2025500589 | M. kansasii | 99.03 | 0.962 | M. kansasii | 635 | 6.38 | 187 | 212 | 165 | 100.00/0.15 |  |
| 13 | Mkan329-013 | 2025500540 | M. kansasii | 99.27 | 0.963 | M. kansasii | 38 | 6.36 | 232 | 192 | 178 | 98.18/0.61 |  |
| 14 | Mkan329-014 | 2025500512 | M. kansasii | 100.0 | 1.0 | M. kansasii | 106 | 6.48 | 246 | 183 | 176 | 100.00/0.15 |  |
| 15 | Mkan329-015 | 2025500415 | M. kansasii | 99.53 | 0.979 | M. kansasii | - | 6.39 | 243 | 180 | 181 | 100.00/0.15 |  |
| 16 | Mkan329-016 | 2025500369 | M. pseudokansasii | 99.86 | 0.979 | M. pseudokansasii | 222 | 6.12 | 258 | 102 | 179 | 97.99/0.00 |  |
| 17 | Mkan329-017 | 2025500342 | M. kansasii | 99.59 | 0.965 | M. kansasii | 38 | 6.54 | 235 | 146 | 165 | 100.00/0.61 |  |
| 18 | Mkan329-018 | 2025500329 | M. persicum | 99.83 | 0.972 | M. persicum | 418 | 6.19 | 229 | 186 | 174 | 99.55/0.68 |  |
| 19 | Mkan329-019 | 2025500189 | M. kansasii | 99.48 | 0.965 | M. kansasii | 38 | 6.45 | 229 | 194 | 168 | 100.00/0.00 |  |
| 20 | Mkan329-020 | 2025500143 | M. kansasii | 99.57 | 0.96 | M. kansasii | 38 | 6.54 | 249 | 146 | 166 | 100.00/0.61 |  |
| 21 | Mkan329-021 | 2025500114 | M. kansasii | 99.61 | 0.939 | M. kansasii | - | 6.45 | 306 | 127 | 173 | 94.83/7.76 | contamination |
| 22 | Mkan329-022 | 2025500093 | M. kansasii | 99.03 | 0.963 | M. kansasii | 635 | 6.38 | 194 | 209 | 191 | 100.00/0.15 |  |
| 23 | Mkan329-023 | 2025500001 | M. pseudokansasii | 99.86 | 0.979 | M. pseudokansasii | 222 | 6.11 | 290 | 101 | 185 | 99.09/0.00 |  |
| 24 | Mkan329-024 | 2025342420 | M. kansasii | 99.78 | 0.981 | M. kansasii | 38 | 6.37 | 204 | 192 | 183 | 100.00/0.15 |  |
| 25 | Mkan329-025 | 2025342047 | M. kansasii | 99.39 | 0.939 | M. kansasii | 38 | 6.73 | 240 | 217 | 165 | 100.00/0.30 |  |
| 26 | Mkan329-026 | 2025341450 | M. persicum | 99.81 | 0.972 | M. persicum | 418 | 6.19 | 235 | 136 | 172 | 99.55/0.68 |  |
| 27 | Mkan329-027 | 2025340467 | M. kansasii | 99.64 | 0.974 | M. kansasii | - | 6.42 | 268 | 110 | 165 | 100.00/0.15 |  |
| 28 | Mkan329-028 | 2025335442 | M. pseudokansasii | 99.84 | 0.938 | M. pseudokansasii | 222 | 6.56 | 413 | 62 | 156 | 98.86/3.25 | low purity |
| 29 | Mkan329-029 | 2025335201 | M. kansasii | 99.31 | 0.97 | M. kansasii | - | 6.38 | 294 | 128 | 186 | 100.00/0.15 |  |
| 30 | Mkan329-030 | 2025333808 | M. attenuatum | 99.57 | 0.954 | M. attenuatum | 743 | 6.36 | 318 | 104 | 180 | 99.55/0.91 |  |
| 31 | Mkan329-031 | 2024500644 | M. kansasii | 99.38 | 0.956 | M. kansasii | 38 | 6.52 | 250 | 163 | 167 | 100.00/0.15 |  |
| 32 | Mkan329-032 | 2024500632 | M. kansasii | 99.34 | 0.955 | M. kansasii | 38 | 6.52 | 254 | 145 | 166 | 100.00/0.15 |  |
| 33 | Mkan329-033 | 2024500579 | M. kansasii | 99.73 | 0.974 | M. kansasii | - | 6.49 | 242 | 209 | 161 | 100.00/0.15 |  |
| 34 | Mkan329-034 | 2024500542 | M. kansasii | 99.99 | 0.993 | M. kansasii | - | 6.36 | 226 | 155 | 172 | 100.00/0.15 |  |
| 35 | Mkan329-035 | 2024500472 | M. kansasii | 99.66 | 0.953 | M. ostraviense | - | 13.05 | 1712 | 34 | 77 | 100.00/113.37 | contamination, low purity, MetaPhlAn differs, genome size, fragmented |
| 36 | Mkan329-036 | 2024500430 | M. kansasii | 100.0 | 0.953 | M. kansasii | - | 6.58 | 288 | 96 | 171 | 96.82/0.30 |  |
| 37 | Mkan329-037 | 2024500391 | M. kansasii | 99.8 | 0.991 | M. kansasii | 38 | 6.37 | 228 | 217 | 173 | 100.00/0.15 |  |
| 38 | Mkan329-038 | 2024500290 | M. kansasii | 99.39 | 0.956 | M. kansasii | 38 | 6.52 | 236 | 182 | 171 | 100.00/0.15 |  |
| 39 | Mkan329-039 | 2024500264 | M. kansasii | 99.77 | 0.98 | M. kansasii | 38 | 6.38 | 225 | 143 | 162 | 100.00/0.15 |  |
| 40 | Mkan329-040 | 2024500011 | M. kansasii | 99.14 | 0.944 | M. kansasii | 609 | 6.51 | 239 | 182 | 167 | 100.00/0.15 |  |
| 41 | Mkan329-041 | 2024341260 | M. pseudokansasii | 99.85 | 0.96 | M. pseudokansasii | 222 | 6.29 | 269 | 97 | 151 | 99.55/0.00 |  |
| 42 | Mkan329-042 | 2024341068 | M. kansasii | 99.39 | 0.96 | M. kansasii | 38 | 6.47 | 185 | 192 | 141 | 100.00/0.00 |  |
| 43 | Mkan329-043 | 2024336973 | M. kansasii | 99.79 | 0.971 | M. kansasii | 38 | 6.49 | 244 | 186 | 154 | 100.00/0.15 |  |
| 44 | Mkan329-044 | 2024335484 | M. kansasii | 99.32 | 0.952 | M. kansasii | 38 | 6.53 | 233 | 201 | 139 | 100.00/0.15 |  |
| 45 | Mkan329-045 | 2024334690 | M. kansasii | 99.34 | 0.97 | M. kansasii | - | 6.38 | 275 | 131 | 154 | 99.55/0.15 |  |
| 46 | Mkan329-046 | 2024334665 | M. persicum | 99.69 | 0.965 | M. persicum | 418 | 6.16 | 229 | 107 | 159 | 100.00/0.68 | low purity |
| 47 | Mkan329-047 | 2024334570 | M. kansasii | 99.49 | 0.972 | M. kansasii | 38 | 6.43 | 228 | 144 | 150 | 100.00/0.15 |  |
| 48 | Mkan329-048 | 2024333287 | M. kansasii | 99.89 | 0.984 | M. kansasii | 609 | 6.41 | 232 | 209 | 177 | 100.00/0.15 |  |
| 49 | Mkan329-049 | 2023500478 | M. kansasii | 99.44 | 0.953 | M. kansasii | 38 | 6.51 | 222 | 158 | 158 | 100.00/0.15 |  |
| 50 | Mkan329-050 | 2023500398 | M. kansasii | 99.77 | 0.982 | M. kansasii | 38 | 6.38 | 236 | 127 | 167 | 100.00/0.15 |  |
| 51 | Mkan329-051 | 2023500230 | M. kansasii | 99.77 | 0.976 | M. kansasii | 38 | 6.40 | 196 | 209 | 162 | 100.00/0.15 |  |
| 52 | Mkan329-052 | 2023500216 | M. persicum | 99.77 | 0.963 | M. persicum | 418 | 6.30 | 208 | 230 | 173 | 99.55/0.45 |  |
| 53 | Mkan329-053 | 2023500140 | M. kansasii | 99.21 | 0.951 | M. kansasii | - | 6.53 | 267 | 158 | 161 | 100.00/0.15 |  |
| 54 | Mkan329-054 | 2023500007 | M. persicum | 99.77 | 0.973 | M. persicum | 418 | 6.09 | 184 | 167 | 186 | 99.55/1.14 |  |
| 55 | Mkan329-055 | 2023335052 | M. persicum | 99.79 | 0.956 | M. persicum | 418 | 5.89 | 1904 | 24 | 150 | 91.01/2.47 | fragmented |
| 56 | Mkan329-056 | 2022500332 | M. kansasii | 99.76 | 0.953 | M. kansasii | 38 | 6.71 | 238 | 158 | 152 | 100.00/0.61 |  |
| 57 | Mkan329-057 | 2019342176 | M. kansasii | 99.36 | 0.966 | M. kansasii | 38 | 6.41 | 254 | 173 | 136 | 100.00/0.15 |  |
| 58 | Mkan329-058 | 2019337931 | M. persicum | 99.65 | 0.96 | M. persicum | 418 | 6.32 | 230 | 109 | 138 | 99.55/0.68 |  |
| 59 | Mkan329-059 | 2019335800 | M. kansasii | 99.45 | 0.955 | M. kansasii | 38 | 6.29 | 241 | 196 | 140 | 96.82/0.15 |  |
| 60 | Mkan329-060 | 2019334540 | M. kansasii | 99.48 | 0.964 | M. kansasii | - | 6.43 | 204 | 139 | 136 | 100.00/0.30 |  |
| 61 | Mkan329-061 | 2019334475 | M. kansasii | 100.0 | 0.994 | M. kansasii | - | 6.37 | 192 | 170 | 165 | 100.00/0.15 |  |
| 62 | Mkan329-062 | 2019334210 | M. kansasii | 99.21 | 0.966 | M. kansasii | 38 | 6.38 | 232 | 146 | 160 | 99.55/0.15 |  |
| 63 | Mkan329-063 | 2019333788 | M. persicum | 99.82 | 0.972 | M. persicum | 418 | 6.49 | 251 | 146 | 145 | 99.55/0.83 |  |
| 64 | Mkan329-064 | 2018500393 | M. kansasii | 99.99 | 1.0 | M. kansasii | 106 | 6.31 | 252 | 155 | 144 | 98.18/0.15 |  |
| 65 | Mkan329-065 | 2018500390 | M. kansasii | 99.99 | 1.0 | M. kansasii | 106 | 6.48 | 267 | 127 | 148 | 100.00/0.15 |  |
| 66 | Mkan329-066 | 2018500358 | M. kansasii | 99.21 | 0.96 | M. kansasii | 38 | 6.50 | 277 | 126 | 149 | 100.00/0.61 |  |
| 67 | Mkan329-067 | 2018500279 | M. kansasii | 99.49 | 0.958 | M. kansasii | - | 6.52 | 259 | 127 | 173 | 100.00/0.15 |  |
| 68 | Mkan329-068 | 2018500230 | M. kansasii | 99.68 | 0.941 | M. kansasii | 814 | 6.62 | 186 | 180 | 166 | 100.00/0.15 |  |
| 69 | Mkan329-069 | 2018500228 | M. persicum | 99.6 | 0.954 | M. persicum | - | 6.16 | 206 | 150 | 178 | 99.09/0.68 |  |
| 70 | Mkan329-070 | 2018500222 | M. kansasii | 100.0 | 0.994 | M. kansasii | - | 6.38 | 192 | 138 | 173 | 100.00/0.15 |  |
| 71 | Mkan329-071 | 2018500096 | M. kansasii | 99.11 | 0.942 | M. kansasii | - | 6.49 | 238 | 146 | 157 | 100.00/0.38 |  |
| 72 | Mkan329-072 | 2018500063 | M. kansasii | 99.49 | 0.97 | M. kansasii | 609 | 6.42 | 276 | 119 | 174 | 100.00/0.15 |  |
| 73 | Mkan329-073 | 2018500044 | M. attenuatum | 99.6 | 0.958 | M. attenuatum | 743 | 6.36 | 368 | 77 | 146 | 99.32/0.91 |  |
| 74 | Mkan329-074 | 2018338007 | M. kansasii | 99.64 | 0.977 | M. kansasii | 38 | 6.39 | 216 | 146 | 162 | 100.00/0.15 |  |
| 75 | Mkan329-075 | 2018337670 | M. kansasii | 99.55 | 0.975 | M. kansasii | 635 | 6.49 | 219 | 146 | 164 | 100.00/0.15 |  |
| 76 | Mkan329-076 | 2018336679 | M. kansasii | 99.23 | 0.939 | M. kansasii | 609 | 6.56 | 232 | 215 | 152 | 100.00/0.15 |  |
| 77 | Mkan329-077 | 2018335175 | M. kansasii | 99.84 | 0.959 | M. kansasii | 38 | 6.58 | 246 | 165 | 178 | 100.00/0.15 |  |
| 78 | Mkan329-078 | 2017500448 | M. pseudokansasii | 99.85 | 0.955 | M. pseudokansasii | 222 | 6.39 | 287 | 97 | 159 | 99.09/0.00 |  |
| 79 | Mkan329-079 | 2017500339 | M. pseudokansasii | 99.83 | 0.975 | M. pseudokansasii | 222 | 6.25 | 277 | 97 | 170 | 99.09/0.00 |  |
| 80 | Mkan329-080 | 2017500308 | M. kansasii | 99.56 | 0.975 | M. kansasii | 635 | 6.39 | 218 | 146 | 156 | 100.00/0.15 |  |
| 81 | Mkan329-081 | 2017500287 | M. pseudokansasii | 99.85 | 0.934 | M. pseudokansasii | 222 | 6.48 | 275 | 102 | 167 | 99.55/0.53 |  |
| 82 | Mkan329-082 | 2017500195 | M. persicum | 99.81 | 0.971 | M. persicum | - | 6.00 | 232 | 158 | 169 | 93.18/0.68 |  |
| 83 | Mkan329-083 | 2017500172 | M. kansasii | 99.75 | 0.954 | M. kansasii | 38 | 6.64 | 262 | 139 | 162 | 100.00/0.15 |  |
| 84 | Mkan329-084 | 2017500086 | M. pseudokansasii | 99.86 | 0.975 | M. pseudokansasii | 222 | 6.31 | 258 | 105 | 172 | 99.55/0.00 |  |
| 85 | Mkan329-085 | 2017500065 | M. persicum | 99.6 | 0.96 | M. persicum | - | 6.21 | 202 | 150 | 152 | 99.55/0.45 |  |
| 86 | Mkan329-086 | 2017500058 | M. kansasii | 99.21 | 0.952 | M. kansasii | 38 | 6.51 | 227 | 161 | 163 | 100.00/0.15 |  |
| 87 | Mkan329-087 | 2017500047 | M. kansasii | 100.0 | 1.0 | M. kansasii | 106 | 6.47 | 267 | 183 | 146 | 100.00/0.15 |  |
| 88 | Mkan329-088 | 2017342194 | M. kansasii | 99.14 | 0.963 | M. kansasii | 38 | 6.46 | 222 | 170 | 132 | 100.00/0.61 |  |
| 89 | Mkan329-089 | 2017338581 | M. kansasii | 99.49 | 0.957 | M. kansasii | 38 | 6.52 | 245 | 148 | 146 | 100.00/0.15 |  |
| 90 | Mkan329-090 | 2017336282 | M. kansasii | 99.7 | 0.979 | M. kansasii | 38 | 6.40 | 219 | 194 | 172 | 100.00/0.15 |  |
| 91 | Mkan329-091 | 2017334009 | M. kansasii | 99.92 | 0.985 | M. kansasii | 38 | 6.38 | 236 | 139 | 180 | 100.00/0.15 |  |
| 92 | Mkan329-092 | 2017333397 | M. persicum | 99.76 | 0.969 | M. persicum | 418 | 6.20 | 262 | 107 | 165 | 99.55/0.45 |  |
| 93 | Mkan329-093 | 2016500351 | M. persicum | 99.78 | 0.971 | M. persicum | 418 | 6.23 | 263 | 136 | 56 | 99.55/0.45 |  |
| 94 | Mkan329-094 | 2016500293 | M. kansasii | 99.77 | 0.945 | M. kansasii | 38 | 6.67 | 255 | 110 | 52 | 100.00/0.15 |  |
| 95 | Mkan329-095 | 2016500284 | M. kansasii | 99.4 | 0.96 | M. kansasii | 38 | 6.25 | 240 | 128 | 65 | 98.18/0.15 |  |
| 96 | Mkan329-096 | 2016500270 | M. kansasii | 99.77 | 0.981 | M. kansasii | 38 | 6.39 | 254 | 127 | 51 | 100.00/0.15 |  |
| 97 | Mkan329-097 | 2016500198 | M. kansasii | 99.45 | 0.957 | M. kansasii | - | 6.52 | 262 | 173 | 68 | 100.00/0.15 |  |
| 98 | Mkan329-098 | 2016500191 | M. kansasii | 99.26 | 0.968 | M. kansasii | 38 | 6.25 | 251 | 126 | 62 | 96.82/0.15 |  |
| 99 | Mkan329-099 | 2016500180 | M. persicum | 99.78 | 0.97 | M. persicum | 418 | 6.22 | 238 | 112 | 53 | 99.55/0.45 |  |
| 101 | Mkan329-101 | 2016500071 | M. kansasii | 99.3 | 0.936 | M. kansasii | 38 | 6.62 | 229 | 132 | 74 | 100.00/0.15 |  |
| 102 | Mkan329-102 | 2016500035 | M. persicum | 99.78 | 0.972 | M. persicum | 418 | 6.34 | 244 | 172 | 70 | 99.55/0.45 |  |
| 103 | Mkan329-103 | 2016500020 | M. persicum | 99.69 | 0.967 | M. persicum | 418 | 6.15 | 209 | 139 | 81 | 100.00/0.45 |  |
| 104 | Mkan329-104 | 2016341346 | M. persicum | 99.78 | 0.969 | M. persicum | 418 | 6.05 | 230 | 143 | 65 | 95.00/0.68 |  |
| 105 | Mkan329-105 | 2016337210 | M. kansasii | 99.55 | 0.965 | M. kansasii | 635 | 6.44 | 235 | 127 | 61 | 100.00/0.15 |  |
| 106 | Mkan329-106 | 2016333922 | M. kansasii | 99.92 | 0.938 | M. kansasii | 635 | 7.40 | 909 | 54 | 57 | 97.84/20.44 | contamination, fragmented |
| 107 | Mkan329-107 | 2015500216 | M. persicum | 99.37 | 0.949 | M. persicum | 418 | 6.34 | 203 | 121 | 73 | 100.00/0.61 |  |
| 109 | Mkan329-109 | 2015500168 | M. kansasii | 99.31 | 0.963 | M. kansasii | 38 | 6.43 | 189 | 156 | 81 | 100.00/0.15 |  |
| 110 | Mkan329-110 | 2015500028 | M. persicum | 99.81 | 0.97 | M. persicum | 418 | 6.20 | 236 | 137 | 74 | 99.55/0.45 |  |
| 111 | Mkan329-111 | 2015179580 | M. kansasii | 99.67 | 0.988 | M. kansasii | 38 | 6.37 | 238 | 134 | 73 | 100.00/0.15 |  |
| 112 | Mkan329-112 | 2015178933 | M. kansasii | 99.89 | 0.989 | M. kansasii | - | 6.38 | 221 | 127 | 64 | 100.00/0.15 |  |
| 113 | Mkan329-113 | 2015178195 | M. persicum | 99.58 | 0.831 | M. persicum | - | 10.98 | 7473 | 5 | 34 | 92.24/61.40 | contamination, low purity, weak GTDB match, genome size, fragmented, low depth |
| 114 | Mkan329-114 | 2015177435 | M. pseudokansasii | 99.86 | 0.98 | M. pseudokansasii | 222 | 6.16 | 280 | 97 | 83 | 99.55/0.00 |  |
| 115 | Mkan329-115 | 2015176560 | M. kansasii | 99.77 | 0.98 | M. kansasii | 38 | 6.48 | 274 | 123 | 59 | 100.00/0.15 |  |
| 116 | Mkan329-116 | 2015176242 | M. kansasii | 99.32 | 0.976 | M. kansasii | 38 | 6.24 | 234 | 175 | 62 | 98.18/0.15 |  |
| 117 | Mkan329-117 | 2014500150 | M. kansasii | 99.99 | 0.958 | M. kansasii | 38 | 6.64 | 274 | 127 | 78 | 100.00/0.30 |  |
| 118 | Mkan329-118 | 2014500099 | M. kansasii | 99.3 | 0.936 | M. kansasii | 38 | 6.62 | 241 | 110 | 71 | 100.00/0.15 |  |
| 119 | Mkan329-119 | 2014500061 | M. pseudokansasii | 99.86 | 0.976 | M. pseudokansasii | 222 | 6.30 | 293 | 101 | 83 | 99.55/0.00 |  |
| 120 | Mkan329-120 | 2014500051 | M. kansasii | 99.64 | 0.981 | M. kansasii | 38 | 6.39 | 233 | 173 | 96 | 100.00/0.15 |  |
| 121 | Mkan329-121 | 2014500042 | M. kansasii | 99.6 | 0.98 | M. kansasii | 38 | 6.39 | 254 | 125 | 89 | 100.00/0.15 |  |
| 122 | Mkan329-122 | 2014500004 | M. kansasii | 99.93 | 0.989 | M. kansasii | 38 | 6.39 | 271 | 134 | 83 | 100.00/0.15 |  |
| 123 | Mkan329-123 | 2014185128 | M. kansasii | 99.26 | 0.95 | M. kansasii | 38 | 6.52 | 228 | 127 | 83 | 100.00/0.15 |  |
| 124 | Mkan329-124 | 2014181818 | M. kansasii | 98.91 | 0.95 | M. kansasii | 609 | 6.47 | 225 | 171 | 85 | 100.00/0.61 |  |
| 125 | Mkan329-125 | 2014178902 | M. pseudokansasii | 99.87 | 0.98 | M. pseudokansasii | 222 | 6.15 | 279 | 104 | 77 | 99.55/0.00 |  |
| 126 | Mkan329-126 |  | M. tuberculosis (control) | 99.99 | 1.0 | M. tuberculosis | 215 | 4.36 | 134 | 114 | 111 | 99.61/0.00 |  |
| 127 | Mkan329-127 |  | M. avium (control) | 99.99 | 1.0 | M. avium | 4 | 4.88 | 90 | 206 | 120 | 100.00/0.00 |  |
| 128 | Mkan329-128 |  | M. kansasii (control) | 99.99 | 1.0 | M. kansasii | 106 | 6.48 | 253 | 132 | 76 | 100.00/0.15 |  |
| 129 | Mkan329-129 |  | M. abscessus (control) | 100.0 | 1.0 | Mycobacteroides abscessus | 5 | 5.08 | 47 | 557 | 101 | 99.44/0.00 |  |
| 130 | Mkan329-130 |  | M. xenopi (control) | 99.79 | 0.978 | M. xenopi | - | 4.62 | 214 | 73 | 115 | 99.09/1.29 |  |
| 131 | Mkan329-131 |  | M. marinum (control) | 98.28 | 0.938 | M. marinum | 580 | 5.67 | 298 | 55 | 83 | 99.55/0.92 |  |
| 132 | Mkan329-132 |  | M. persicum (control) | 99.97 | 0.99 | M. persicum | 418 | 6.19 | 281 | 118 | 70 | 100.00/0.45 |  |
| 133 | Mkan329-133 |  | M. pseudokansasii (control) | 99.99 | 0.999 | M. pseudokansasii | 867 | 6.24 | 318 | 104 | 85 | 99.55/0.00 |  |

## Caveats

- Species is the GTDB-Tk call (ANI to the GTDB representative). MetaPhlAn4 is a cross-check; its database has no *M. innocens*, so such isolates show up as *M. kansasii*.
- `rMLST_best_species` is `species` for every sample (the rMLST step returns no usable result); it is not reported here. The 16S call is also not reported: it cannot separate the kansasii complex.
- MLST ST `-` means no sequence type was assigned.
- The pipeline's own QC (`<run>_quality_QC.csv`) marks the total length of every isolate as FAIL (threshold not suited to this group), so it is not used for the flags above.
- A mixed culture or contamination makes the GTDB call unreliable; check the flagged isolates before using their species or SNP tree position.
