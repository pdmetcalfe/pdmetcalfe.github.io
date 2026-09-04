#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [sas7bdat vs parquet redux])
#metadata((
  title: "parquet vs sas7bdat redux",
  kind: "post",
  date: "2026-09-03",
  tags: ("data", "statistics", "rants"),
  summary: "sas7bdat must die",
)) <website-metadata>

#title()

I may have #link("apache-arrow-ftw.html")[ranted about `.sas7bdat` before]. The following code is instructive.

```r
sas_size <- file.size(Sys.readlink("adlbc.sas7bdat"))

start <- Sys.time()
adlbc <- haven::read_sas("adlbc.sas7bdat")
end_read <- Sys.time()
arrow::write_parquet(adlbc, "adlbc.pq", compression="uncompressed")
end_parquet <- Sys.time()
adlbc_2 <- arrow::read_parquet("adlbc.pq") |> as.data.frame()
end_read_parquet <- Sys.time()

parquet_size <- file.size("adlbc.pq")

read_time <- end_read - start
write_time <- end_parquet - end_read
read_pq_time <- end_read_parquet - end_parquet

cat("=== File sizes ===\n")
cat(sprintf("sas7bdat: %s bytes\n", format(sas_size, big.mark = ",")))
cat(sprintf("parquet : %s bytes\n", format(parquet_size, big.mark = ",")))

cat("\n=== Haven benchmark times ===\n")
cat(sprintf("read_sas:      %.3f %s\n", read_time, units(read_time)))
cat(sprintf("write_parquet: %.3f %s\n", write_time, units(write_time)))
cat(sprintf("read_parquet:  %.3f %s\n", read_pq_time, units(read_pq_time)))
```

Question... guess the output. The file sizes are notable: that which in
`.sas7bdat` is 15 MB is three quarters of a megabyte in _uncompressed_ `.parquet`.

```
=== File sizes ===
sas7bdat: 14,680,064 bytes
parquet : 773,980 bytes
```

The timings are also educational (note that I'm very carefully doing
the `read_parquet` into a data frame rather than leaving it arrow-side).

```
=== Haven benchmark times ===
read_sas:      0.643 secs
write_parquet: 0.183 secs
read_parquet:  0.021 secs
```

TLDR... Do Do #link("https://arrow.apache.org/")[Arrow], Do Not Do `.sas7bdat`.
You too can save a factor of 20 on your storage costs *and* make your
data scientists happy into the bargain.