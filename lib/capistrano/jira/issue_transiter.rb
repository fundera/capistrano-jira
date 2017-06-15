require 'pry'
module Capistrano
  module Jira
    class IssueTransiter
      attr_reader :issue
      
      include ErrorHelpers

      def initialize(issue)
        @issue = issue
      end

      def transit
        validate_transition
        execute
      end

      private

      def transition
        @transition ||= issue.transitions.all.find do |t|
          t.attrs['name'].casecmp(fetch(:jira_transition_name)).zero?
        end
      end

      def validate_transition
        return if transition
        raise TransitionError,
              "Transition #{fetch(:jira_transition_name)} not available"
      end

      def execute
        issue.transitions.build.save!(transition_hash)
        issue.comments.build.save!(comment_hash)
        issue.save(version_hash)
      rescue JIRA::HTTPError => e
        raise TransitionError, error_message(e)
      end

      def transition_hash
        { transition: { id: transition.id } }
      end

      def version_hash
        {
          fields: {
            fixVersions: [
              {
                name: fetch(:jira_fix_version)
              }
            ]
          }
        }
      end

      def comment_hash
        {
          body: 'Issue transited automatically during deployment.'
        }
      end
    end
  end
end
