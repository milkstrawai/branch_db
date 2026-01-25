module BranchDb
  module GitUtils
    def current_branch = `git symbolic-ref HEAD 2>/dev/null`.chomp.sub("refs/heads/", "")

    def git_branches
      output = `git branch --format='%(refname:short)' 2>/dev/null`
      output.split("\n").map(&:strip).reject(&:empty?)
    end

    def parent_branch = @parent_branch ||= detect_parent_branch

    def reset_parent_cache! = @parent_branch = nil

    private

    def detect_parent_branch
      return ENV["BRANCH_DB_PARENT"] if ENV["BRANCH_DB_PARENT"]

      detect_parent_from_reflog || BranchDb.configuration.main_branch
    end

    def detect_parent_from_reflog
      current = current_branch
      return nil if current.empty?

      `git reflog show --format='%gs' -n 100 2>/dev/null`.each_line do |line|
        parent = extract_parent_from_reflog_line(line.chomp, current)
        return parent if parent
      end
      nil
    end

    def extract_parent_from_reflog_line(line, current)
      return nil unless line =~ /\Acheckout: moving from (.+) to #{Regexp.escape(current)}\z/

      parent = ::Regexp.last_match(1).strip
      return nil if parent == current || parent =~ /\A[a-f0-9]{40}\z/

      parent
    end
  end
end
