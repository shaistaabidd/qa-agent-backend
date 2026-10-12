# Request/job instrumentation for QA runs — see lib/qa_probe.rb. Does nothing
# unless enabled (development by default) and QA_PROBE_TOKEN is set.
require Rails.root.join('lib/qa_probe').to_s

QaProbe.install!(Rails.application.config)
