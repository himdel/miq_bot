require 'benchmark'

module GitHubApi
  def self.connect(username, password)
    @user = GitHubApi::User.new
    @user.client ||= Octokit::Client.new(:login => username, :password => password, :auto_paginate => true)

    return @user
  end

  def self.execute(client, cmd, *args)
    p [ :execute, cmd, *args ]
    if DANGEROUS.include? cmd
      logger.warning("Skipping #{cmd} #{args.inspect}")
      return nil
    end

    rate_limit_remaining = client.rate_limit.remaining
    logger.debug("Executing #{cmd} #{args.inspect}...api calls remaining #{rate_limit_remaining}")
    val = nil
    t = Benchmark.realtime { val = client.send(cmd, *args) }
    logger.debug("Executing #{cmd} #{args.inspect}...Completed in #{t}s and used #{rate_limit_remaining - client.rate_limit.remaining} api calls")
    p val
    val
  rescue => err
    logger.error("Executing #{cmd} #{args.inspect}...Failed in #{t}s")
    logger.error("#{err.class}: #{err}")
    logger.error(err.backtrace.join("\n"))
    raise
  end

  def self.logger
    Rails.logger
  end

  DANGEROUS = %i( add_comment add_labels_to_an_issue remove_label update_issue mark_thread_as_read )
end
