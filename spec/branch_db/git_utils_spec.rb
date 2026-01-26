RSpec.describe BranchDb::GitUtils do
  # Test GitUtils through Naming module since it's extended there
  let(:naming) { BranchDb::Naming }

  describe "#current_branch" do
    it "returns the current git branch name" do
      allow(naming).to receive(:`).with("git symbolic-ref HEAD 2>/dev/null")
                                  .and_return("refs/heads/feature-auth\n")

      expect(naming.current_branch).to eq("feature-auth")
    end

    it "returns empty string when not in a git repo" do
      allow(naming).to receive(:`).with("git symbolic-ref HEAD 2>/dev/null").and_return("")
      expect(naming.current_branch).to eq("")
    end
  end

  describe "#git_branches" do
    it "returns list of local git branches" do
      allow(naming).to receive(:`).with("git branch --format='%(refname:short)' 2>/dev/null")
                                  .and_return("main\nfeature-a\nfeature-b\n")
      expect(naming.git_branches).to eq(%w[main feature-a feature-b])
    end

    it "returns empty array when not in git repo" do
      allow(naming).to receive(:`).with("git branch --format='%(refname:short)' 2>/dev/null")
                                  .and_return("")
      expect(naming.git_branches).to eq([])
    end

    it "strips whitespace from branch names" do
      allow(naming).to receive(:`).with("git branch --format='%(refname:short)' 2>/dev/null")
                                  .and_return("  main  \n  feature  \n")
      expect(naming.git_branches).to eq(%w[main feature])
    end
  end

  describe "#parent_branch" do
    context "when BRANCH_DB_PARENT env var is set" do
      around do |example|
        original = ENV.fetch("BRANCH_DB_PARENT", nil)
        ENV["BRANCH_DB_PARENT"] = "feature-parent"
        example.run
        ENV["BRANCH_DB_PARENT"] = original
      end

      it "returns the env var value" do
        expect(naming.parent_branch).to eq("feature-parent")
      end

      it "ignores git reflog" do
        allow(naming).to receive(:current_branch).and_return("feature-child")
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return("checkout: moving from other-branch to feature-child\n")

        expect(naming.parent_branch).to eq("feature-parent")
      end
    end

    context "when detecting from git reflog" do
      before do
        allow(naming).to receive(:current_branch).and_return("feature-child")
      end

      it "finds the parent branch from reflog checkout entry" do
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return("checkout: moving from feature-parent to feature-child\n")

        expect(naming.parent_branch).to eq("feature-parent")
      end

      it "skips SHA-based parents (detached HEAD)" do
        sha = "abc123def456789012345678901234567890abcd"
        reflog = "checkout: moving from #{sha} to feature-child\ncheckout: moving from real-parent to #{sha}\n"
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return(reflog)

        expect(naming.parent_branch).to eq("main")
      end

      it "skips entries where parent equals current branch" do
        reflog = "checkout: moving from feature-child to feature-child\n" \
                 "checkout: moving from real-parent to feature-child\n"
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return(reflog)
        expect(naming.parent_branch).to eq("real-parent")
      end

      it "falls back to main when no valid parent found" do
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return("commit: some message\n")

        expect(naming.parent_branch).to eq("main")
      end

      it "falls back to main when reflog is empty" do
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return("")

        expect(naming.parent_branch).to eq("main")
      end
    end

    context "when not in a git repo" do
      it "falls back to main branch" do
        allow(naming).to receive(:current_branch).and_return("")
        expect(naming.parent_branch).to eq("main")
      end
    end

    context "with caching" do
      before do
        allow(naming).to receive(:current_branch).and_return("feature-child")
        allow(naming).to receive(:`).with("git reflog show --format='%gs' -n 1000 2>/dev/null")
                                    .and_return("checkout: moving from feature-parent to feature-child\n")
      end

      it "caches the result" do
        2.times { naming.parent_branch }
        expect(naming).to have_received(:`).once
      end

      it "clears cache when reset_parent_cache! is called" do
        naming.parent_branch
        naming.reset_parent_cache!
        naming.parent_branch
        expect(naming).to have_received(:`).twice
      end
    end
  end
end
