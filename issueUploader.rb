#!/usr/bin/env ruby

require "json"
board = JSON.parse(File.read("./wolaBoard.json"))
board["pipelines"].each do |columns|
  if columns["name"] == "Review/QA"
    columns["issues"].each do |issue|
      puts "https://app.zenhub.com/workspaces/wola-5cb0b30b1be1263b113a0ec6/issues/wolaapplication/wola_maps_android/#{issue["issue_number"]}"
    end
  end
end
