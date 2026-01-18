RSpec.describe BranchDb::Logging do
  let(:test_class) do
    Class.new do
      include BranchDb::Logging

      attr_reader :output

      def initialize(output:, prefix: true)
        @output = output
        @prefix = prefix
      end
    end
  end

  let(:output) { StringIO.new }

  describe "#log" do
    context "with prefix enabled (default)" do
      let(:instance) { test_class.new(output: output) }

      it "outputs message with [branch_db] prefix" do
        instance.send(:log, "test message")
        expect(output.string).to eq("[branch_db] test message\n")
      end
    end

    context "with prefix disabled" do
      let(:instance) { test_class.new(output: output, prefix: false) }

      it "outputs message without prefix" do
        instance.send(:log, "test message")
        expect(output.string).to eq("test message\n")
      end
    end
  end

  describe "#log_indented" do
    context "with prefix enabled (default)" do
      let(:instance) { test_class.new(output: output) }

      it "outputs message with [branch_db] prefix and indentation" do
        instance.send(:log_indented, "indented message")
        expect(output.string).to eq("[branch_db]    indented message\n")
      end
    end

    context "with prefix disabled" do
      let(:instance) { test_class.new(output: output, prefix: false) }

      it "outputs message with indentation but no prefix" do
        instance.send(:log_indented, "indented message")
        expect(output.string).to eq("   indented message\n")
      end
    end
  end

  describe "#prefix?" do
    context "when @prefix is not set" do
      let(:instance) { test_class.new(output: output) }

      it "returns true" do
        expect(instance.send(:prefix?)).to be true
      end
    end

    context "when @prefix is true" do
      let(:instance) { test_class.new(output: output, prefix: true) }

      it "returns true" do
        expect(instance.send(:prefix?)).to be true
      end
    end

    context "when @prefix is false" do
      let(:instance) { test_class.new(output: output, prefix: false) }

      it "returns false" do
        expect(instance.send(:prefix?)).to be false
      end
    end
  end
end
