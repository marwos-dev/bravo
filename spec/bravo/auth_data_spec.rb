# encoding: utf-8
require 'spec_helper'

describe 'Bravo::AuthData' do
  describe '.fetch' do
    context 'previous logged in (el CEE ya posee un TA valido el acceso al WSN solicitado)' do
      let(:file_path) { 'spec/fixtures/token_and_sign_test.yml' }

      it 'does not call login' do
        allow(Bravo::AuthData).to receive(:access_ticket_expired?).and_return(false)
        allow(Bravo::AuthData).to receive(:todays_data_file_name).and_return(file_path)

        expect(Bravo::Wsaa).not_to receive(:login)

        Bravo::AuthData.fetch
      end
    end

    context 'not logged in' do
      it 'creates constants for todays data' do
        allow(Bravo::AuthData).to receive(:access_ticket_expired?).and_return(true)
        allow(Bravo::Wsaa).to receive(:call_wsaa).and_return(%w[token sign])

        Bravo::AuthData.fetch

        expect(Bravo::TOKEN).not_to be_nil
        puts Bravo::TOKEN
      end
    end
  end

  describe '.access_ticket_expired?' do
    it 'returns true when constant EXPIRED_AT does not exists' do
      Bravo.send(:remove_const, 'EXPIRE_AT')
      Bravo::AuthData.access_ticket_expired?.should eq true
    end

    context 'when access ticket has expired' do
      it 'returns true' do
        expired_at = Time.now - 54_000 # 15 hours
        Bravo.const_set('EXPIRE_AT', expired_at)
        Bravo::AuthData.access_ticket_expired?.should eq true
      end
    end

    context 'when access ticket has not expired' do
      it 'returns false' do
        expire_at = Time.now + 54_000 # 15 hours
        Bravo.const_set('EXPIRE_AT', expire_at)
        Bravo::AuthData.access_ticket_expired?.should eq false
      end
    end
  end
end
