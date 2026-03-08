#!/usr/bin/env ruby
require 'json'

# Simple one-shot processor to verify per-message logs can be parsed and prepared
# without starting the long-running watcher.

CONFIG_PATH = File.expand_path('~/repos/finance/email_parsers.json')
EMAIL_LOGS_DIR = File.expand_path('~/email_logs')
DB_PATH = File.expand_path('~/repos/finance/spending.db')

def load_config
  JSON.parse(File.read(CONFIG_PATH))
end

def process_file(filepath, parsers)
  data = JSON.parse(File.read(filepath)) rescue nil
  return unless data
  # Support both the old threads format and the new per-message logs
  messages = data['messages'] || (data['threads'] && data['threads'][0] && data['threads'][0]['messages']) || []
  messages.each do |msg|
    payload = msg['payload'] || {}
    headers = {}
    (payload['headers'] || []).each { |h| headers[h['name']] = h['value'] }
    from_val = headers['From'] || ''
    subject = headers['Subject'] || ''
    body = msg['body']

    parsers.each do |parser|
      if from_val.downcase.include?(parser['from_pattern'].to_s.downcase) || parser['from_pattern'].nil?
        # Try to parse the email body with the same logic as production
        parsed = nil
        if parser['amount_pattern'] || parser['merchant_pattern']
          # Minimal parsing implementation to illustrate behavior
          amount = body.to_s[/#{parser['amount_pattern']}/, 1] if parser['amount_pattern']
          merchant = body.to_s[/#{parser['merchant_pattern']}/, 1] if parser['merchant_pattern']
          date = Time.now.strftime('%Y-%m-%d')
          if amount && merchant
            parsed = { date: date, merchant: merchant, amount: amount.to_f, card_last_four: nil }
          end
        end
        puts parsed ? "Parsed: #{parsed[:date]} #{parsed[:merchant]} $#{parsed[:amount]}" : 'Parsed: no data'
      end
    end
  end
end

parsers = load_config
Dir.glob(File.join(EMAIL_LOGS_DIR, '*.json')).each do |filepath|
  process_file(filepath, parsers)
end
