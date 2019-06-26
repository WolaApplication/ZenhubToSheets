# Upload issues from ZH to Google Sheets

This script has been made to save time when transfering issues from Review/QA column in the Zenhub board to an Excel page, to check if they are fixed or not.
We use this to have a resume of the passed issues and the failed ones, with notes on the failed ones that are easy to see and pass up the command chain.

### Initial setup:
* 'git clone'
* 'bundle install'
* Generate a '.env' file that contains these keys:
  * token
  * github_username
  * github_token
* get Google sheets API access

### How to use this script:

Once the initial setup is complete, in your working directory:
* 'ruby issueUploader.rb Android|iOS [Zenhub board name]'

The Zenhub board name defaults to 'Review/QA' if there is no parameter given.

