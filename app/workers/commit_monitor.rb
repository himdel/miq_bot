require 'yaml'

class CommitMonitor
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def self.options
    @options ||= YAML.load_file(Rails.root.join('config/commit_monitor.yml'))
  end

  def self.product
    @product ||= options["product"]
  end

  # commit handlers expect to handle a specific commit at a time.
  #
  # Example: A commit message checker that will check for URLs and act upon them.
  def self.commit_handlers
    @commit_handlers ||= handlers_for(:commit)
  end

  # commit_range handlers expect to handle a range of commits as a group.
  #
  # Example: A style/syntax/warning checker on a PR branch, where we only want
  #   to check the new commits, but as a group, since newer commits may fix
  #   issues in prior commits.
  def self.commit_range_handlers
    @commit_range_handlers ||= handlers_for(:commit_range)
  end

  # branch handlers expect to handle an entire branch at once.
  #
  # Example: A PR branch mergability tester to see if the entire branch can be
  #   merged or not.
  def self.branch_handlers
    @branch_handlers ||= handlers_for(:branch)
  end

  def perform
    process_branches
  end

  private

  attr_reader :repo, :git, :branch

  def process_branches
    CommitMonitorRepo.includes(:branches).each do |repo|
      @repo = repo
      repo.with_git_service do |git|
        @git = git
        repo.branches.each do |branch|
          @branch = branch
          process_branch
        end
      end
    end
  end

  def process_branch
    git.checkout(branch.name)
    update_branch

    commits = new_commits
    process_handlers(commits)

    branch.last_checked_on = Time.now.utc
    branch.last_commit     = commits.last if commits.any?
    branch.save!
  end

  def update_branch
    branch.pull_request? ? git.update_pr_branch(branch.name) : git.pull
  end

  def branch_mode
    branch.pull_request? ? :pr : :regular
  end

  def new_commits
    send("new_commits_on_#{branch_mode}_branch")
  end

  def new_commits_on_regular_branch
    git.new_commits(branch.last_commit)
  end

  def new_commits_on_pr_branch
    all_commits = git.new_commits(git.merge_base(branch.name, "master"))
    comparison  = compare_commits_list(branch.commits_list, all_commits)

    # Adjust the commits_list to deal with any rebasing or force pushing
    branch.commits_list = all_commits

    comparison[:right_only]
  end

  def compare_commits_list(left, right)
    return {:same => left.dup, :left_only => [], :right_only => []} if left == right

    combined = left.zip_stretched(right)
    pivot    = combined.index { |c1, c2| c1 != c2 } || -1

    same = left[0...pivot]
    left_only, right_only = combined[pivot..-1].transpose.collect(&:compact)

    {:same => same, :left_only => left_only, :right_only => right_only}
  end

  #
  # Handler processing methods
  #

  def self.handlers_for(type)
    workers_path = Rails.root.join("app/workers")
    Dir.glob(workers_path.join("commit_monitor_handlers/#{type}/*.rb")).collect do |f|
      path = Pathname.new(f).relative_path_from(workers_path).to_s
      path.chomp(".rb").classify.constantize
    end
  end
  private_class_method(:handlers_for)

  def process_handlers(commits)
    process_commit_handlers(commits)
    process_commit_range_handlers(commits)
    process_branch_handlers
  end

  def filter_handlers(handlers)
    handlers.select { |h| h.handled_branch_modes.include?(branch_mode) }
  end

  def commit_handlers
    filter_handlers(self.class.commit_handlers)
  end

  def commit_range_handlers
    filter_handlers(self.class.commit_range_handlers)
  end

  def branch_handlers
    filter_handlers(self.class.branch_handlers)
  end

  def process_commit_handlers(commits)
    commits.each do |commit|
      message = git.commit_message(commit)
      commit_handlers.each do |h|
        h.perform_async(branch.id, commit, :message => message)
      end
    end
  end

  def process_commit_range_handlers(commits)
    return if commits.empty?
    commit_range_handlers.each do |h|
      h.perform_async(branch.id, commits)
    end
  end

  def process_branch_handlers
    branch_handlers.each do |h|
      h.perform_async(branch.id)
    end
  end
end
