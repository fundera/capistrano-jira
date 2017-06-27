namespace :load do
  task :defaults do
    set :jira_username,              ENV['CAPISTRANO_JIRA_USERNAME']
    set :jira_password,              ENV['CAPISTRANO_JIRA_PASSWORD']
    set :jira_site,                  ENV['CAPISTRANO_JIRA_SITE']
    set :jira_project_key,           nil
    set :jira_status_name,           nil
    set :jira_transition_name,       nil
    set :jira_filter_jql,            nil
    set :jira_comment_on_transition, true
    set :jira_fix_version,           DateTime.now.strftime('%Y%m%d %H%M')
  end
end

namespace :jira do
  desc 'Find and transit possible JIRA issues'
  task :find_and_transit do |_t|
    on roles(:jira) do |_host|
      info 'Looking for issues'
      begin
        issues = Capistrano::Jira::IssueFinder.new.find
        info "creating version #{fetch(:jira_fix_version)}"
        fv = Capistrano::Jira.client.Version.build
        fv.save({
          name: fetch(:jira_fix_version),
          project: fetch(:jira_project_key),
        })
        fv.fetch
        issues.each do |issue|
          begin
            Capistrano::Jira::IssueTransiter.new(issue).transit
            info "#{issue.key}\t\u{2713} Transited"
          rescue Capistrano::Jira::TransitionError => e
            warn "#{issue.key}\t\u{2717} #{e.message}"
          end
        end
        fv.save({released: true})
      rescue Capistrano::Jira::FinderError => e
        error "#{e.class} #{e.message}"
      end
    end
  end

  desc 'Check JIRA setup'
  task :check do
    on roles(:jira) do |_host|
      errored = false
      required_params =
        %i(jira_username jira_password jira_site jira_project_key
           jira_status_name jira_transition_name jira_comment_on_transition)

      puts '=> Required params'
      required_params.each do |param|
        print "#{param} = "
        if fetch(param).nil? || fetch(param) == ''
          puts '!!!!!! EMPTY !!!!!!'
          errored = true
        else
          puts param == :jira_password ? '**********' : fetch(param)
        end
      end
      raise StandardError, 'Not all required parameters are set' if errored
      puts '<= OK'

      puts '=> Checking connection'
      projects = ::Capistrano::Jira.client.Project.all
      puts '<= OK'

      puts '=> Checking for given project key'
      exist = projects.any? { |project| project.key == fetch(:jira_project_key) }
      unless exist
        raise StandardError, "Project #{fetch(:jira_project_key)} not found"
      end
      puts '<= OK'
    end
  end

  after 'deploy:finished', 'jira:find_and_transit'
end
