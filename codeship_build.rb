# Schema Info
#
# Table name: codeship_builds
#
#  id                 :integer
#  build_url          :string
#  badge_url          :string
#  commit_url         :string
#  project_id         :integer
#  build_id           :integer
#  status             :string
#  project_full_name  :string
#  commit_id          :string
#  short_commit_id    :string
#  message            :text
#  committer          :string
#  branch             :string
#  badge_comment_sent :boolean
#  created_at         :datetime
#  updated_at         :datetime
#

require './bitbucket_pull_request'

class CodeshipBuild < Sequel::Model

  plugin :validation_helpers
  plugin :timestamps, update_on_create: true
  plugin :update_or_create

  STATUSES = ['testing', 'error', 'success', 'stopped', 'waiting']

  def bitbucket_pull_request
    BitbucketPullRequest.first repository_full_name: project_full_name,
                               last_commit_sha: commit_id
  end

  def validate
    super
    validates_presence [:build_url, :badge_url, :commit_url, :project_id,
                        :build_id, :status, :project_full_name, :commit_id,
                        :short_commit_id, :message, :committer, :branch]
    validates_unique :build_id
    validates_includes self.class::STATUSES, :status
  end

  def status_badge_markdown
    "[![Codeship build for #{project_full_name}](#{badge_url})](#{build_url})"
  end

  def badge_status
    case status
    when 'success', 'error' then status
    when 'testing', 'stopped', 'waiting' then 'testing'
    end
  end

  def after_save
    super

    require 'pry'; binding.pry
    handle_pull_request_approval!
    send_badge_comment_if_needed!
  end

  def before_save
    super

    update_pull_request!
  end

  private

  def send_badge_comment_if_needed!
    return if badge_comment_sent || bitbucket_pull_request.nil?

    if bitbucket_pull_request.send_comment!(status_badge_markdown)
      update(badge_comment_sent: true)
    end
  end

  def handle_pull_request_approval!
    return if bitbucket_pull_request.nil?

    case status
    when 'success'
      bitbucket_pull_request.approve!
    else
      bitbucket_pull_request.unapprove!
    end
  end

  def update_pull_request!
    return if bitbucket_pull_request.nil?

    bitbucket_pull_request.update_last_commit_sha!
  end

end
