# mail-extration-tool

Tool to scrap emails from a list of websites. Takes the list of websites as a parameter, in format TBS (tab separated values) e.g:

WEBUID&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;WEBSITE&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;URL

abc123&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Website 1&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;http://websitename1.url

azk988&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Website 2&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;http://websitename2.url

gju386&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Website N&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;http://websitenameN.url

Usage example: `./extract_mail_from_url.sh list_of_websites_and_urls_in_tbs_format.tbs`.

The tool downloads the website using `wget` and then searches for different email addresses formats with regular expressions:
 * text@text.domain `[a-z0-9.-]@[a-z0-9.-].[a-z]`
 * text (at) text.domain `[a-z0-9.-] (at) [a-z0-9.-].[a-z]`
 * text(at)text.domain `[a-z0-9.-](at)[a-z0-9.-].[a-z]`
 * text[at]text[dot]domain `[a-z0-9.-][at][a-z0-9.-][dot][a-z]`
 * text[ät]text.domain `[a-z0-9.-][ät][a-z0-9.-].[a-z]`
 * text [at] text.domain `[a-z0-9.-][at][a-z0-9.-].[a-z]`
 * text [at] text [punkt] domain `[a-z0-9.-][at][a-z0-9.-][punkt][a-z]`
 * text(at)text(dot)domain `[a-z0-9.-](at)[a-z0-9.-](dot)[a-z]`
 * text at text.domain `[a-z0-9.-] at [a-z0-9.-].[a-z]`
 * text [at] text [dot] domain `[a-z0-9.-] [at] [a-z0-9.-] [dot] [a-z]`
 
Configurable options in the tool:
* TIMEOUT: default `40` seconds; doesn't work in MacOS sinte `timeout` is not a standard command in `darwin`. If you want this option to work in MacOS, read https://gist.github.com/dasgoll/7b1a796d6e42cb66508bc504bb518f82
* RETRIES: default `3` times; number of times the website will be tried to get downloaded. 
* FILTER_LIST_FILE: default `filter_list`; name of the filter list of optional words to exclude from the emails addresses scrapped by the tool.
* TMP_FILE: default `"website_"${WEBSITE_LIST_FILE}`; temporary file where the website is downloaded and then deleted after being processed for email scrapping.
* OUTPUT_FILE: default `${WEBSITE_LIST_FILE}"_WITH_MAILS.tsv"`; filename where the extration tool will output the results of the scrapping.
