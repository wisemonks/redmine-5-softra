# frozen_string_literal: true

module RedmineReformat
  class Execution
    class ReformatWorkerProgress < Progress
      def initialize(ipc)
        super()
        @ipc = ipc
      end

      def start(item, jobcount, count)
        super
        @ipc.send(:start, item, jobcount, count)
      end

      def progress(item, count)
        super
        @ipc.send(:progress, item, count)
      end

      def finish
        @ipc.send(:finish)
      end

      def complete?
        return false unless super
        @ipc.send(:items_completion)
        ign, c, n = @ipc.recv(:items_completion_res)
        c == n
      end

      def item_jobs_started?
        # single worker
        true
      end

      def reporting?
        false
      end
    end
  end
end
