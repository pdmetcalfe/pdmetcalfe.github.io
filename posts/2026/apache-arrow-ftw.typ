#import "/.calepin/calepin.typ" as calepin
#calepin.setup(eval: false)
#set document(title: [Apache Arrow FTW])
#metadata((
  title: "Apache Arrow FTW",
  kind: "post",
  date: "2026-09-02",
  tags: ("programming", "data", "rants"),
  summary: "the data world has changed",
)) <website-metadata>

#title()

I have spent enough time in the SAS-adjacent parts of drug development to
violently react whenever _anyone_ mentions `.sas7bdat` or `.csv` as
standards for tabular data. There is now one true answer for tabular data
files, and that is called #link("https://parquet.apache.org/")[parquet], and
there is no reason for any in-memory tabular data formats beyond
#link("https://arrow.apache.org/")[arrow].

= Why `.sas7bdat` must die

`.sas7bdat` is an opaque undocumented binary file format that means that
continually paying money to the SAS Institute is the only way to get guaranteed
access to your data. People have had to reverse engineer the format to get
`.sas7bdat` data into tools like R or python, and it is hard not to see the
requirement for this reverse engineering as a cynical attempt by the
SAS Institute to keep milking money from a captive audience. Sure, it's *your*
data, you just have to pay me if you want to understand it.

At a binary level `.sas7bdat` files know about floating point numbers and byte
strings. That's it. No bools, integers, enums, structs, dates, datetimes or anything
else#footnote[Dates and datetimes are hacked in by tagging a floating point number
with one of many "formats", conflating "representation" and "display".].
And just to add insult to injury, in the Real World™ string encoding is a solved
problem (use UTF8 and be done) --- in SAS files you still need to worry about
character encoding#footnote[I once had a discussion with the folks at SAS. It went a
bit like this:

#table(
  columns: 2,
  [*SAS bod*], [Strings are stored as ASCII.],
  [*your hero*], [Oh, so how do you represent things like `ñ`?],
  [*SAS bod*], [That just goes into the file as is.],
  [*your hero*], [So by 'ASCII' you mean 'not ASCII'?]
)
].

= Why `.csv` must die

`.csv` is at least not an opaque undocumented binary file format. `.csv` is an
opaque undocumented text file format. It lacks any concept of types or type safety;
fundamentally everything is either a string or guesswork. (What's the difference between
`""` and missing?) And the idea that --- for the sizes of data we're caring about
--- human-readable is a win is laughable. But I suppose that if you want to edit your
data in Excel#footnote[🤮] then CSV is a good thing.

= Why the world is better now

This is now this thing called #link("https://parquet.apache.org/")[Apache Parquet]#footnote[I missed
parquet emerging. It came from the spark world originally, and my view on Java is perfectly summarized by
the old joke: "I really liked the idea of _Die Java Enterprise Server_  until
I realised it was written in German".]: a
type-safe file format for tabular data. It's readable by *anything*, and it deserializes
into #link("https://arrow.apache.org/")[Apache Arrow] --- a shared, efficient in-memory
representation that is agreed on across multiple programming languages. That means you can
read your data in python, transfer it to R, do the analysis, transfer to rust, all without
barriers, and the data is stored in columnar formats that make it hyper-efficient for CPUs
and GPUs to scan through it and do the computations they need to do.

Because these problems are now _solved_ there's a whole class of problems you no longer need to
worry about. So stop worrying. Use Arrow and Parquet and make your lives easier.
