require 'spec_helper'

describe DatabaseSanitizer do
  describe '#extract_transformer', nodb: true do
    context 'should return nil for no transformer' do
      ['no tag comment', nil, '', 'sanitize no tag'].each do |comment|
        it { expect(described_class.extract_transformer comment).to be_nil }
      end
    end

    context 'should return transformer' do
      [
       'sanitize: test_tr',
       'random sanitize: test_tr comment',
       'some sanitize: test_tr, sanitize: other',
       'without sanitize:test_tr space',
       'trailing sanitize: test_tr'
      ].each do |comment|
        it { expect(described_class.extract_transformer comment).to eq('test_tr') }
      end
    end
  end

  describe '#read_comments' do
    before do
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define do
          change_table :test do |t|
            t.string :field3
            t.string :field4
          end
        end
      end
      comments = {
        field1: 'comment no tag',
        field2: nil,
        field3: 'comment sanitize: name',
        field4: 'sanitize:email'
      }.each { |col, com| ActiveRecord::Base.connection.set_column_comment :test, col, com }
    end

    context 'some defined' do
      it 'should get transformers' do
        transformers = described_class.read_comments(ActiveRecord::Base.connection, [:test])[:test]
        expect(transformers[:field1]).to be_nil
        expect(transformers[:field2]).to be_nil
        expect(transformers[:field3]).to be_kind_of(Proc)
        expect(transformers[:field4]).to be_kind_of(Proc)
      end
    end

    context 'some undefined' do
      before { ActiveRecord::Base.connection.set_column_comment :test, :field2, 'sanitize:undef' }
      it 'should abort' do
        expect(lambda {described_class.read_comments ActiveRecord::Base.connection, [:test]}).to raise_error(SystemExit)
      end
    end
  end
end
