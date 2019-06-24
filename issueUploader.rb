#!/usr/bin/env ruby

require "json"
require 'dotenv/load'
require "net/http"

def issues
  url = 'https://api.zenhub.io/p2/workspaces/5cb0b30b1be1263b113a0ec6/repositories/131278619/board'
  uri = URI(url)
  issues = Array.new
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => true)  do |http|
    request = Net::HTTP::Get.new(uri)
    request['Content-Type'] = 'application/json'
    request['X-Authentication-Token'] = ENV['token']

    http.request(request)
  end

  board = JSON.parse(response.body)

  board["pipelines"].each do |columns|
    if columns["name"] == "Icebox"
      columns["issues"].each do |issue|
        issues.push(issue['issue_number']) 
      end
    end
  end
  issues
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
  puts issue['title']

end

issues.each do |issue|
  # Insert each element in a dictionary
  issue_url(issue)
  issue_name(issue)
end
