module Capistrano
  module Jira
    class VersionMaker

      def initialize(issue)
        @issue = issue
      end

      def create_version
        @issue.versions.build(fix_version_hash)
      end

      def fix_version_hash
        {
          name: fetch(:jira_fix_version),
          project: fetch(:jira_project_key),
        }
      end
    end
  end
end
