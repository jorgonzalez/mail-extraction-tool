# mail-extration-tool

Tool to scrap emails from a list of websites. Takes the list of websites as a parameter, in format TBS (tab separated values; Website Name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;http://websitename.url).

E.g. `./extract_mail_from_business_url.sh list_of_business_and_urls_in_tbs_format.tbs`.

The tool downloads the website using `wget` and then searches for different email addresses formats with regular expressions:
 * text@text.domain `[a-z0-9.-]@[a-z0-9.-].[a-z]`
 * text (at) text.domain `[a-z0-9.-] (at) [a-z0-9.-].[a-z]`
 * text(at)text.domain `[a-z0-9.-](at)[a-z0-9.-].[a-z]`
 * text[at]text[dot]domain `[a-z0-9.-][at][a-z0-9.-][dot][a-z]`
 
`filter_list` 

Configurable options in the tool:
* TIMEOUT: default `40` seconds; doesn't work in MacOS sinte `timeout` is not a standard command in `darwin`. If you want this option to work in MacOS, read https://gist.github.com/dasgoll/7b1a796d6e42cb66508bc504bb518f82
* RETRIES: default `3` times; number of times the website will be tried to get downloaded. 
* FILTER_LIST_FILE: default `filter_list`; name of the filter list of optional words to exclude from the emails addresses scrapped by the tool.
* TMP_FILE: default `website_"${BUSINESS_LIST_FILE}`; temporary file where the website is downloaded and then deleted after being processed for email scrapping.
* OUTPUT_FILE: default `${BUSINESS_LIST_FILE}_WITH_MAILS.tsv`; filename where the extration tool will output the results of the scrapping.
