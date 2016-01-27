require 'rails_helper'

describe UserSession do
  describe '#create' do
    it 'bootstraps using User object' do
      user = create(:user)
      session = UserSession.create(user)
      expect(session.cdx_token).to be_nil
      expect_redis_to_have_key(session.token)
    end

    it 'persists cdx_token' do
      user = create(:user)
      session = UserSession.create(user, 'abc123')
      expect(session.cdx_token).to eq 'abc123'
      expect_redis_to_have_key(session.token)
    end
  end

  describe '#new' do
    it 'finds user via token' do
      user = create(:user)
      session = UserSession.create(user)
      session_from_token = UserSession.new(session.token)
      expect(session_from_token.user).to eq user
      expect_redis_to_have_key(session.token)
    end
  end

  describe '#get + #set' do
    it 'persists arbitrary values' do
      user = create(:user)
      session = UserSession.create(user)
      session.set(foo: 'bar')
      session_from_token = UserSession.new(session.token)
      expect(session_from_token.get(:foo)).to eq 'bar'
    end

    it 'sets multiple, gets singular' do
      user = create(:user)
      session = UserSession.create(user)
      session.set(foo: 'bar', color: 'green')
      expect(session.get(:color)).to eq 'green'
    end
  end

  describe '#expire' do
    it 'zaps the session from the store' do
      user = create(:user)
      session = UserSession.create(user)
      session.set(foo: 'bar')
      token = session.token
      session.expire
      expect(UserSession.new(token).get(:foo)).to eq nil
    end
  end

  describe '#touch' do
    it 'resets the updated_at value' do
      user = create(:user)
      session = UserSession.create(user)
      updated_at = session.updated_at
      sleep 1
      session.touch
      expect(session.updated_at.to_s).to_not eq updated_at.to_s
    end
  end

  def expect_redis_to_have_key(key)
    expect(UserSession.redis.get(key)).to_not be_nil
  end
end
