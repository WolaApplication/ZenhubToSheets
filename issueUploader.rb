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
  payload = Array.new(namesAndUrls.length){Array.new(1){" "}}
  namesAndUrls.each_with_index do |hash, index|
    flat_hash = [*hash]
    payload[index] << %(=HYPERLINK("#{flat_hash[1]}";"#{flat_hash[0]}"))
  end
  payload
end

def zenhub_workspace_id
  if PROJECT == 'wola' 
    workspace_id = '5cb0b30b1be1263b113a0ec6'
  elsif PROJECT == 'sister'
    workspace_id = '5cffe9a440bac60294a06f36'
  elsif PROJECT == 'wolaschools'
    workspace_id = '5cd435823cc1905bb9c3d564'
  elsif PROJECT == 'wave'
    workspace_id = '5cb0b0991be1263b113a0e8a'
  else abort script
  end
  workspace_id
end

def zenhub_repo_id
  if PROJECT == 'wola' && PLATFORM == 'android'
    repo_id = '131278619'
  elsif PROJECT == 'wola' && PLATFORM == 'ios'
    repo_id = '132564584'
  elsif PROJECT == 'sister' && PLATFORM == 'android'
    repo_id = '191421403'
  elsif PROJECT == 'sister' && PLATFORM == 'ios'
    repo_id = '191421547'
  elsif PROJECT == 'wolaschools' && PLATFORM == 'android'
    repo_id = '122591800'
  elsif PROJECT == 'wolaschools' && PLATFORM == 'ios'
    repo_id = '121603793'
  elsif PROJECT == 'wave' && PLATFORM == 'android'
    repo_id = '97030648'
  elsif PROJECT == 'wave' && PLATFORM == 'ios'
    repo_id = '97011462'
  else abort script
  end
  repo_id
end

def issues
  workspace_id = zenhub_workspace_id
  repo_id = zenhub_repo_id
  url = "https://api.zenhub.io/p2/workspaces/#{workspace_id}/repositories/#{repo_id}/board" 
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
    if columns["name"] == COLUMN
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

def sendDataToGoogleSheets(namesAndUrls)
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

def project_id
  if PROJECT == 'wola' 
    project_id = 'wola-5cb0b30b1be1263b113a0ec6'
  elsif PROJECT == 'sister'
    project_id = 'sister-5cffe9a440bac60294a06f36'
  elsif PROJECT == 'wolaschools'
    project_id = 'wola-schools-5cd435823cc1905bb9c3d564'
  elsif PROJECT == 'wave'
    project_id = 'wave-5cb0b0991be1263b113a0e8a'
  else abort script
  end
  project_id
end

def zenhub_board
  if PROJECT == 'wola' 
    project_board = 'wola_maps'
  elsif PROJECT == 'sister'
    project_board = 'sister'
  elsif PROJECT == 'wolaschools'
    project_board = 'schools'
  elsif PROJECT == 'wave'
    project_board = 'wave'
  else abort script
  end
  project_board
end

def issue_url(issue)
  project = project_id
  project_board = zenhub_board
  "https://app.zenhub.com/workspaces/#{project}/issues/wolaapplication/#{project_board}_#{PLATFORM}/#{issue}" 
end

def github_project
  if PROJECT == 'wola' 
    project_board = 'wola_maps_'
  elsif PROJECT == 'sister'
    project_board = 'sister_'
  elsif PROJECT == 'wolaschools' && PLATFORM == 'android'
    project_board = 'schools_'
  elsif PROJECT == 'wolaschools' && PLATFORM == 'ios'
    project_board = 'wola_schools_'
  elsif PROJECT == 'wave'
    project_board = 'wave_'
  else abort script
  end
  project_board

end

def issue_name(issue)
  project_board = github_project
  uri = URI("https://api.github.com/repos/WolaApplication/#{project_board}#{PLATFORM}/issues/#{issue}")
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

def abort_script
abort('This program requires at least two parameters.
Project: Wola, Sister, WolaSchools or Wave
Board: either iOS or Android
The others are optional.
Column: Defaults to Review/QA')  
end

abort_script if ARGV.length == 0

# This value can be either wola, Sister, WolaSchools or Wave
PROJECT = ARGV[0].downcase 

# This value should be either Android or iOS
PLATFORM = ARGV[1].downcase 
ARGV.length == 3 ? COLUMN = ARGV[2] : COLUMN = 'Review/QA'
abort_script if ARGV.length > 3

namesAndUrls = Hash.new
issues.each do |issue|
  namesAndUrls[issue_name(issue)] = issue_url(issue)
end

sendDataToGoogleSheets(namesAndUrls)
