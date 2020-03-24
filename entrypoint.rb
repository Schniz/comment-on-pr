#!/usr/bin/env ruby

require "json"
require "octokit"

UniqueId = Struct.new(:id) {
  def as_html_comment
    "<!-- unique_id: #{id} -->"
  end

  def in_str?(str)
    str.include?(as_html_comment)
  end
}

def find_pr_number(event)
  if ENV.fetch("GITHUB_EVENT_NAME") == "pull_request"
    return event["number"]
  else
    pulls = github.pull_requests(repo, state: "open")

    push_head = event["after"]
    pr_found = pulls.find { |pr| pr["head"]["sha"] == push_head }

    unless pr_found
      puts "Couldn't find an open pull request for branch with head at #{push_head}."
      exit(1)
    end
    return pr_found["number"]
  end
end

json = File.read(ENV.fetch("GITHUB_EVENT_PATH"))
event = JSON.parse(json)

github_token = ARGV.fetch(0) { raise "GitHub token not provided" }
file_path = ARGV.fetch(1) { raise "File path not provided" }
unique_id = ARGV[2] && UniqueId.new(ARGV[2])

github = Octokit::Client.new(access_token: github_token)
repo = event["repository"]["full_name"]
pr_number = find_pr_number(event)
message = "#{unique_id&.as_html_comment || ''}\n#{File.read(file_path)}"

coms = github.issue_comments(repo, pr_number)
duplicate = coms.find { |c|
  c["user"]["login"] == "github-actions[bot]" &&
    (unique_id&.in_str?(c["body"]) || message == c["body"])
}

if duplicate
  github.update_comment(repo, duplicate[:id], message)
else
  github.add_comment(repo, pr_number, message)
end
