require 'octokit'

USER_NAME = ENV['NIPPO_GITHUB_USER_NAME']

class Nippo
  def pull_requests
    @pull_requests ||= PullRequests.new(all_user_events)
  end

  def client
    @@client = Octokit::Client.new(login: USER_NAME, access_token: ENV['NIPPO_GITHUB_API_TOKEN'])
  end

  def all_user_events
    @all_user_events ||= (user_events + user_public_events).uniq{|e| e.id}
  end

  def user_events
    @@user_events ||= client.user_events(USER_NAME, per_page: 100)
  end

  def user_public_events
    @@user_public_events ||= client.user_public_events(USER_NAME, per_page: 100)
  end

  class Events
    def initialize(events)
      @events = events
    end

    protected
    def list
      @events.select{|event| event.type == self.type}
    end

    def events_by_action(action)
      list.select{|event| event.payload.action == action}
    end
  end

  module IssueBaseEvents
    def assigned
      events_by_action('assigned')
    end

    def unassigned
      events_by_action('unassigned')
    end

    def labeled
      events_by_action('labeled')
    end

    def unlabeled
      events_by_action('unlabeled')
    end

    def opened
      events_by_action('opened')
    end

    def closed
      events_by_action('closed')
    end

    def reopened
      events_by_action('reopened')
    end

    def synchronize
      events_by_action('synchronize')
    end
  end

  class PullRequests < Events
    include IssueBaseEvents

    def type
      'PullRequestEvent'
    end

    def all
      list
    end

    def opened
      exclude_ids = (merged + unmerged).map{|e| e.payload.pull_request.id}
      super.select{|event| not exclude_ids.include?(event.payload.pull_request.id) }
    end

    def opened_at(date)
      opened.select{|event| event.payload.pull_request.created_at.to_date == date }
    end

    def merged
      closed.select{|event| event.payload.pull_request.merged}
    end

    def merged_at(date)
      merged.select{|event| event.payload.pull_request.merged_at.to_date == date}
    end

    def unmerged
      closed.select{|event| !event.payload.pull_request.merged}
    end

    def unmerged_at(date)
      unmerged.select{|event| event.payload.pull_request.closed_at.to_date == date}
    end
  end
end

def puts_pr_md(title, events, indent)
  spaces = '    '
  print spaces * indent, "* #{title}\n" unless events.empty?
  events.each do |pull_request|
    print spaces * (indent + 1), "* [#{pull_request.payload.pull_request.title}](#{pull_request.payload.pull_request.html_url})\n"
  end
end
nippo = Nippo.new

puts '* pull_request' unless nippo.pull_requests.all.empty?
puts_pr_md('merged', nippo.pull_requests.merged_at(Date.today), 1)
puts_pr_md('rejected', nippo.pull_requests.unmerged_at(Date.today), 1)
puts_pr_md('opened', nippo.pull_requests.opened_at(Date.today), 1)
