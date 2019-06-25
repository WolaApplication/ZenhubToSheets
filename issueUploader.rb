#!/usr/bin/env ruby

require "json"
require 'dotenv/load'
require "net/http"

require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "issueUploader".freeze
CREDENTIALS_PATH = "credentials.json".freeze
# The file token.yaml stores the user's access and refresh tokens, and is
# created automatically when the authorization flow completes for the first
# time.
TOKEN_PATH = "token.yaml".freeze
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS

def generate_payload(namesAndUrls)
  payload = Array.new(namesAndUrls.length){Array.new(1){0}}
  namesAndUrls.each_with_index do |hash, index|
    flat_hash = [*hash]
    payload[index] = %(=HYPERLINK("#{flat_hash[1]}";"#{flat_hash[0]}"))
  end
  payload
end

def issues
  url = 'https://api.zenhub.io/p2/workspaces/5cb0b30b1be1263b113a0ec6/repositories/131278619/board'
  issues = Array.new
  uri = URI(url)
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true)  do |http|
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    request['X-Authentication-Token'] = ENV['token']

    http.request(request)
  end

  board = JSON.parse(response.body)
  board["pipelines"].each do |columns|
    if columns["name"] == "Backlog"
      columns["issues"].each do |issue|
        issues.push(issue['issue_number'])
      end
    end
  end
  issues
end


##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = "default"
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

def sendDataToGoogleSheest(namesAndUrls)
  # Initialize the API
  service = Google::Apis::SheetsV4::SheetsService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize

  # Prints the names and majors of students in a sample spreadsheet:
  # https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
  # Hemos usado la URL https://docs.google.com/spreadsheets/d/104U6ZuIXaG_sic_FOmfME_eSS13uhFrjj3vTdQ6lgJ4/edit#gid=0 y hemos sacado el id de ella
  spreadsheet_id = "104U6ZuIXaG_sic_FOmfME_eSS13uhFrjj3vTdQ6lgJ4"
  range_name = "Hoja 1!A1"
  value_input_option = 'USER_ENTERED'
  values = generate_payload(namesAndUrls)
  data = [
    {
      range: range_name,
      values: values
    },
  ]
  value_range_object = Google::Apis::SheetsV4::ValueRange.new(range: range_name,
                                                              values: values)
  result = service.update_spreadsheet_value(spreadsheet_id,
                                            range_name,
                                            value_range_object,
                                            value_input_option: value_input_option)
  puts "#{result.updated_cells} cells updated."
end

def issue_url(issue)
  "https://app.zenhub.com/workspaces/wola-5cb0b30b1be1263b113a0ec6/issues/wolaapplication/wola_maps_android/#{issue}"
end

def issue_name(issue)
  uri = URI("https://api.github.com/repos/WolaApplication/wola_maps_android/issues/#{issue}")
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(ENV['github_username'], ENV['github_token'])
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/vnd.github.v3+json'

    http.request(request)
  end
  issue = JSON.parse(response.body)
  issue['title']

end

namesAndUrls = Hash.new
issues.each do |issue|
  namesAndUrls[issue_name(issue)] = issue_url(issue)
end
p generate_payload(namesAndUrls)


#sendDataToGoogleSheest(namesAndUrls)
