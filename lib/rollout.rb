class Rollout
  def initialize(redis, features=nil)
    @redis  = redis
    @features = features
    @groups = {"all" => lambda { |user| true }}
  end

  def activate_group(feature, group)
    activate(group_key(feature), group)
  end

  def deactivate_group(feature, group)
    deactivate(group_key(feature), group)
  end

  def deactivate_all(feature)
    deactivate_feature(group_key(feature))
    deactivate_feature(user_key(feature))
    deactivate_feature(percentage_key(feature))
  end

  def activate_user(feature, user)
    activate(user_key(feature), user.id)
  end

  def deactivate_user(feature, user)
    deactivate(user_key(feature), user.id)
  end

  def define_group(group, &block)
    @groups[group.to_s] = block
  end

  def active?(feature, user)
    user_in_active_group?(feature, user) ||
      user_active?(feature, user) ||
        user_within_active_percentage?(feature, user)
  end

  def activate_percentage(feature, percentage)
    key = percentage_key(feature)
    raise 'Invalid feature' unless valid_feature?(key)
    @redis.set(key, percentage)
  end

  def deactivate_percentage(feature)
    deactivate_feature(percentage_key(feature))
  end

  def registered_features
    @features
  end

  def active_features
    active_keys = @redis.keys('feature:*')
    active_keys.collect { |key| feature_name(key) }.uniq
  end

  private
    def key(name)
      "feature:#{name}"
    end

    def group_key(name)
      "#{key(name)}:groups"
    end

    def user_key(name)
      "#{key(name)}:users"
    end

    def percentage_key(name)
      "#{key(name)}:percentage"
    end

    def user_in_active_group?(feature, user)
      (@redis.smembers(group_key(feature)) || []).any? { |group| @groups.key?(group) && @groups[group].call(user) }
    end

    def user_active?(feature, user)
      user ? @redis.sismember(user_key(feature), user.id) : false
    end

    def user_within_active_percentage?(feature, user)
      percentage = @redis.get(percentage_key(feature))
      return false if percentage.nil?
      user.id % 100 < percentage.to_i
    end

    def activate(key, member)
      raise 'Invalid feature' unless valid_feature?(key)
      @redis.sadd(key, member)
    end

    def deactivate(key, member)
      raise 'Invalid feature' unless valid_feature?(key)
      @redis.srem(key, member)
    end

    def deactivate_feature(key)
      raise 'Invalid feature' unless valid_feature?(key)
      @redis.del(key)
    end

    def valid_feature?(key)
      @features ? @features.include?(feature_name(key)) : true
    end

    def feature_name(key)
      key.split(':')[1]
    end
end
