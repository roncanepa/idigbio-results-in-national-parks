# iDigBio Results in National Parks

Example code for a presentation during the ninth annual ADBC Summit, October 1-3, 2019, in Gainesville, Florida.  https://www.idigbio.org/content/adbc-summit-2019

Shows a proof-of-concept for fetching records from the iDigBio search API and determining which records have geopoints that lie within national parks in the state of Florida.

Note: you'll want to download the shape data from the NPS and put them into the `data` directory (and then adjust the path in the Rmd).

See also: Co-presenter @ekrimmel's example: https://github.com/ekrimmel/idigbio-api-dq-geo

iDigBio Search API documentation:
https://github.com/iDigBio/idigbio-search-api/wiki

National Parks Service boundary datasets
https://catalog.data.gov/dataset/national-parks

# Abstract
R and the iDigBio API: Enabling Exploration and Discovery

APIs and their use: a non-technical overview of the iDigBio Application Programming Interface (APIs) and example use cases for both data providers and downstream data consumers. 

The rise of shared, open data brings with it an increased need for technical skillsets and an understanding of where and how the various pieces fit together in the bigger picture.  This non-technical session will first give a brief overview of what an API is and provide a basic highlight of iDigBio's API offerings.  Then, using R in combination with the iDigBio API, the bulk of the hour will present an example use case for both data providers and downstream data consumers, with a focus on outputs such as graphs, summarized tables, and other visualizations.
