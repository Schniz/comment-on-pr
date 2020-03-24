#!/usr/bin/env ruby

require "json"
require "octokit"

json = File.read(ENV.fetch("GITHUB_EVENT_PATH"))
event = JSON.parse(json)

if ARGV.empty?
  puts "Missing arguments"
  exit(1)
end

github_token, file_path, unique_id = ARGV

github = Octokit::Client.new(access_token: github_token)

repo = event["repository"]["full_name"]

if ENV.fetch("GITHUB_EVENT_NAME") == "pull_request"
  pr_number = event["number"]
else
  pulls = github.pull_requests(repo, state: "open")

  push_head = event["after"]
  pr_found = pulls.find { |pr| pr["head"]["sha"] == push_head }

  unless pr_found
    puts "Couldn't find an open pull request for branch with head at #{push_head}."
    exit(1)
  end
  pr_number = pr_found["number"]
end
unique_id_comment = if unique_id.nil?
  ""
else
  %(<!-- comment_id: #{unique_id} -->)
end

message = unique_id_comment + "\n" + File.read(file_path)

coms = github.issue_comments(repo, pr_number)
duplicate = coms.find { |c|
  c["user"]["login"] == "github-actions[bot]" &&
    !unique_id.nil? &&
    c["body"].include?(unique_id_comment)
}

if duplicate
  github.update_comment(repo, duplicate[:id], message)
else
  github.add_comment(repo, pr_number, message)
end
