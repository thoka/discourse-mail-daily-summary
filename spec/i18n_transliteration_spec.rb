require 'rails_helper'
require 'yaml'

RSpec.describe 'Discourse Plugin I18n Transliteration Validation' do
  # Focus on German locales to prevent false positives in English fallback strings
  let(:locale_files) do
    Dir.glob(File.expand_path('../../config/locales/*de*.{yml,yaml}', __FILE__))
  end

  let(:forbidden_patterns) do
    [
      # Core concepts and frequency
      /(?i)\baktivitaet\w*/,
      /(?i)\w*haeufig\w*/,
      /(?i)\bregelmaessig\w*/,
      /(?i)\btaeglich\w*/,
      /(?i)\bwoechentlich\w*/,

      # Verbs and actions
      /(?i)\baender\w*/,
      /(?i)\berhaelt\w*/,
      /(?i)\bmoecht\w*/,
      /(?i)\bueber\w*/,
      /(?i)\bwaehl\w*/,
      /(?i)\w*fueg\w*/,
      /(?i)\w*loesch\w*/,
      /(?i)\w*pruef\w*/,

      # Nouns and entities
      /(?i)\bbeitraeg\w*/,
      /(?i)\bgefaellt\b/,
      /(?i)\bmenue\w*/,
      /(?i)\bschluessel\w*/,
      /(?i)\w*laenge\w*/,

      # Prepositions, adjectives, and others
      /\bfuer\b/,
      /(?i)\bzurueck\b/,
      /(?i)\bunabhaengig\w*/,
      /(?i)\bspaeter\w*/,
      /(?i)\bgueltig\w*/,
      /(?i)\b(haette|waere|wuerde|koennte)\b/
    ]
  end

  it 'contains no legacy transliterations in german locales' do
    errors = []

    locale_files.each do |file|
      begin
        translations = YAML.load_file(file, aliases: true)
        check_node(translations, file, [], errors)
      rescue StandardError => e
        errors << "YAML Parse Error in #{file}: #{e.message}"
      end
    end

    error_message = "Transliteration errors found in German locales:\n#{errors.join("\n")}"
    expect(errors).to be_empty, error_message
  end

  def check_node(node, file, path, errors)
    case node
    when Hash
      node.each do |key, value|
        check_node(value, file, path + [key], errors)
      end
    when Array
      node.each_with_index do |value, index|
        check_node(value, file, path + [index], errors)
      end
    when String
      forbidden_patterns.each do |pattern|
        if node.match?(pattern)
          errors << "- File: #{File.basename(file)} | Key: [#{path.join('.')}] | Pattern: #{pattern.source} | Value: '#{node}'"
        end
      end
    end
  end
end