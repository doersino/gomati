# gomati

*A simple Google Maps tile downloader and stitcher.*


## Setup & Usage

Since Gomati is a **humble shell script**, you'll need `bash`, along with common command-line utilities – the only ones I'm not confident you already have are `curl` and `imagemagick`. Your package manager probably provides them.

Using this tool is as simple as **entering your desired latitude and longitude** in the source code, optionally taking a peek at the other parameters you can modify, and running:

```
bash gomati.sh
```

A more detailed **list of requirements and usage/configuration instructions**, along with a couple of tips and tricks, is **located at the top of `gomati.sh`**.

![GOMATI_ZOOM=15 GOMATI_LATITUDE=43.078899 GOMATI_LONGITUDE=-79.072873 GOMATI_WIDTH=16 GOMATI_HEIGHT=6 GOMATI_RESIZE=1500x1000 bash gomati.sh](example.jpg)


## FAQ

### Why the name?

Gomati stands for **Go**ogle **Ma**ps **Ti**les and is apparently also a [river in India](https://en.wikipedia.org/wiki/Gomti_River).

### Does this violate Google's terms of use?

Probably. I haven't checked. But they haven't banned my IP for downloading tens of thousands of map tiles during development and testing, so you're probably good as long as you don't go crazy downloading a centimeter-scale map of your country?

### What's the maximum map size?

The limiting factor is probably RAM during the stitching step: I've grabbed an 80-by-80 tile map (that's 6400 tiles for those of you keeping track at home) of my hometown, and ImageMagick ate about 12 GB of RAM while stitching them together into a 420M pixel image.

### Why is this tool so slow?

As it's a shell script, there's zero multithreading and a whole bunch of context-switching overhead, plus I made a real fancy progress indicator that's updated in a tight loop. I should have implemented this in Python – and I would've, if only I had anticipated the amount of feature creep I ended up sneaking in.

(The slowness isn't an issue if you use Gomati as I indend to use it: occasionally grabbing a 100ish tile map.)

### This thing only does satellite images, I want my money back!

Not a question, but sure: 💵

### You know, it'd be really neat if there was, like, a Twitter bot based on this tool!

Not a question, but sure: Meet [@americasquared](https://twitter.com/americasquared).

### Something is broken – can you fix it?

Possibly. Please feel free to [file an issue](https://github.com/doersino/gomati/issues) – I'll be sure to take a look!
