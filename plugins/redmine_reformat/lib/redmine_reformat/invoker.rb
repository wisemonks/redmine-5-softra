# frozen_string_literal: true

module RedmineReformat
  class Invoker
    attr_reader :to_formatting, :dryrun, :workers
    Ipc = RedmineReformat::Execution::Ipc

    def initialize(to_formatting: nil, converters_json: nil, dryrun: false, workers: 1)
      @to_formatting = to_formatting
      @dryrun = !!dryrun
      @converter = RedmineReformat::Converters::from_json(converters_json) if converters_json
      @workers = [workers, 1].max
    end

    def run
      STDOUT.sync = true
      STDERR.sync = true
      if @workers == 1
        convert_redmine(RedmineReformat::Execution::Progress.new)
      else
        multi_run
      end
    end

    private
    def convert_redmine(progress, ipc = nil)
      exn = RedmineReformat::Execution.new(progress, ipc)
      exn.dryrun = @dryrun
      exn.converter = @converter
      exn.to_formatting = @to_formatting
      ConvertRedmine.call(exn)
    end

    def multi_run
      ppipes = 2.times.collect{IO.pipe}
      wpipes = @workers.times.collect{IO.pipe}
      pids = @workers.times.collect do |i|
        Process.fork do
          progress_ipc = Ipc.new("Worker #{i} Progress", ppipes, 0)
          progress = RedmineReformat::Execution::ReformatWorkerProgress.new(progress_ipc)
          worker_ipc = Ipc.new("Worker #{i}", wpipes, i)
          convert_redmine(progress, worker_ipc)
          exit 0
        end
      end
      wpipes.flatten.each{|fd| fd.close}
      progress_srv_ipc = Ipc.new("Progress collector", ppipes, 1)
      progress = RedmineReformat::Execution::Progress.new
      progress.server(progress_srv_ipc)
      Process.waitall
    end
  end
end
