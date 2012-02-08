require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Rollout" do
  let(:redis) { MockRedis.new }

  subject { Rollout.new(redis) }

  describe "when a group is activated" do
    before do
      subject.define_group(:fivesonly) { |user| user.id == 5 }
      subject.activate_group(:chat, :fivesonly)
    end

    it "the feature is active for users for which the block evaluates to true" do
      subject.should be_active(:chat, stub(:id => 5))
    end

    it "is not active for users for which the block evaluates to false" do
      subject.should_not be_active(:chat, stub(:id => 1))
    end

    it "is not active if a group is found in Redis but not defined in Rollout" do
      subject.activate_group(:chat, :fake)
      subject.should_not be_active(:chat, stub(:id => 1))
    end
  end

  describe "the default all group" do
    before do
      subject.activate_group(:chat, :all)
    end

    it "evaluates to true no matter what" do
      subject.should be_active(:chat, stub(:id => 0))
    end
  end

  describe "deactivating a group" do
    before do
      subject.define_group(:fivesonly) { |user| user.id == 5 }
      subject.activate_group(:chat, :all)
      subject.activate_group(:chat, :fivesonly)
      subject.deactivate_group(:chat, :all)
    end

    it "deactivates the rules for that group" do
      subject.should_not be_active(:chat, stub(:id => 10))
    end

    it "leaves the other groups active" do
      subject.should be_active(:chat, stub(:id => 5))
    end
  end

  describe "deactivating a feature completely" do
    before do
      subject.define_group(:fivesonly) { |user| user.id == 5 }
      subject.activate_group(:chat, :all)
      subject.activate_group(:chat, :fivesonly)
      subject.activate_user(:chat, stub(:id => 51))
      subject.activate_percentage(:chat, 100)
      subject.deactivate_all(:chat)
    end

    it "removes all of the groups" do
      subject.should_not be_active(:chat, stub(:id => 0))
    end

    it "removes all of the users" do
      subject.should_not be_active(:chat, stub(:id => 51))
    end

    it "removes the percentage" do
      subject.should_not be_active(:chat, stub(:id => 24))
    end
  end

  describe "activating a specific user" do
    before do
      subject.activate_user(:chat, stub(:id => 42))
    end

    it "is active for that user" do
      subject.should be_active(:chat, stub(:id => 42))
    end

    it "remains inactive for other users" do
      subject.should_not be_active(:chat, stub(:id => 24))
    end
  end

  describe "deactivating a specific user" do
    before do
      subject.activate_user(:chat, stub(:id => 42))
      subject.activate_user(:chat, stub(:id => 24))
      subject.deactivate_user(:chat, stub(:id => 42))
    end

    it "that user should no longer be active" do
      subject.should_not be_active(:chat, stub(:id => 42))
    end

    it "remains active for other active users" do
      subject.should be_active(:chat, stub(:id => 24))
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      subject.activate_percentage(:chat, 20)
    end

    it "activates the feature for that percentage of the users" do
      (1..120).select { |id| subject.active?(:chat, stub(:id => id)) }.length.should == 39
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      subject.activate_percentage(:chat, 20)
    end

    it "activates the feature for that percentage of the users" do
      (1..200).select { |id| subject.active?(:chat, stub(:id => id)) }.length.should == 40
    end
  end

  describe "activating a feature for a percentage of users" do
    before do
      subject.activate_percentage(:chat, 5)
    end

    it "activates the feature for that percentage of the users" do
      (1..100).select { |id| subject.active?(:chat, stub(:id => id)) }.length.should == 5
    end
  end


  describe "deactivating the percentage of users" do
    before do
      subject.activate_percentage(:chat, 100)
      subject.deactivate_percentage(:chat)
    end

    it "becomes inactivate for all users" do
      subject.should_not be_active(:chat, stub(:id => 24))
    end

    it "becomes inactivate for a nil user (not logged in)" do
      subject.should_not be_active(:chat, nil)
    end
  end


  describe "with a limited set of valid features" do
    let(:valid_features) { %w(chat comment moderate admin) }

    subject { Rollout.new(redis, valid_features) }

    describe "active features" do
      it "should return names for all active features" do
        subject.define_group(:fivesonly) { |user| user.id == 5 }
        subject.activate_group(:chat, :all)
        subject.activate_group(:comment, :fivesonly)
        subject.activate_user(:moderate, stub(:id => 51))
        subject.activate_percentage(:admin, 100)
        subject.active_features.sort.should == %w(admin chat comment moderate)
      end
    end

    describe "registered features" do
      it "should conatin all valid features" do
        subject.registered_features.should == valid_features
      end
    end

    describe "with a valid feature" do
      let(:valid_feature) { valid_features.sample }

      describe "activating" do

        describe "for a specific user" do
          it "should activate user" do
            user = stub(:id => 42)
            subject.activate_user(valid_feature, user)
            subject.should be_active(valid_feature, user)
          end
        end

        describe "for the default all group" do
          it "should activate all users" do
            subject.activate_group(valid_feature, :all)
            subject.should be_active(valid_feature, stub(:id => 19))
          end
        end

        describe "for a group" do
          before :each do
            subject.define_group(:fivesonly) { |user| user.id == 5 }
          end

          it "should activate group" do
            user = stub(:id => 5)
            subject.activate_group(valid_feature, :fivesonly)
            subject.should be_active(valid_feature, user)
          end
        end

        describe "for a percentage of users" do
          it "should activate percentage of users" do
            subject.activate_percentage(valid_feature, 10)
            (1..100).select { |id| subject.active?(valid_feature, stub(:id => id)) }.length.should == 10
          end
        end

      end

      describe "deactivating" do

        describe "for a specific user" do
          it "should deactivate user" do
            user = stub(:id => 42)
            subject.activate_user(valid_feature, user)
            subject.should be_active(valid_feature, user)
            subject.deactivate_user(valid_feature, user)
            subject.should_not be_active(valid_feature, user)
          end
        end

        describe "for the default all group" do
          it "should deactivate all users" do
            subject.activate_group(valid_feature, :all)
            (1..100).select { |id| subject.active?(valid_feature, stub(:id => id)) }.length.should == 100
            subject.deactivate_group(valid_feature, :all)
            (1..100).select { |id| subject.active?(valid_feature, stub(:id => id)) }.should be_empty
          end
        end

        describe "for a group" do
          before :each do
            subject.define_group(:fivesonly) { |user| user.id == 5 }
          end

          it "should deactivate group members" do
            user = stub(:id => 5)
            subject.activate_group(valid_feature, :fivesonly)
            subject.should be_active(valid_feature, user)
            subject.deactivate_group(valid_feature, :fivesonly)
            subject.should_not be_active(valid_feature, user)
          end
        end

        describe "for a percentage of users" do
          it "should deactivate all users" do
            subject.activate_percentage(valid_feature, 100)
            (1..100).select { |id| subject.active?(valid_feature, stub(:id => id)) }.length.should == 100
            subject.deactivate_percentage(valid_feature)
            (1..100).select { |id| subject.active?(valid_feature, stub(:id => id)) }.should be_empty
          end
        end
      end

      describe "a feature completely" do
        before :each do
          subject.define_group(:fivesonly) { |user| user.id == 5 }
          subject.activate_group(valid_feature, :all)
          subject.activate_group(valid_feature, :fivesonly)
          subject.activate_user(valid_feature, stub(:id => 51))
          subject.activate_percentage(valid_feature, 100)
          subject.deactivate_all(valid_feature)
        end

        it "removes all of the groups" do
          subject.should_not be_active(valid_feature, stub(:id => 0))
        end

        it "removes all of the users" do
          subject.should_not be_active(valid_feature, stub(:id => 51))
        end

        it "removes the percentage" do
          subject.should_not be_active(valid_feature, stub(:id => 24))
        end

      end
    end

    describe "with an invalid feature" do
      let(:invalid_feature) { :invalid }

      describe "attempting to activate" do

        describe "for a specific user" do
          it "should raise error" do
            expect { subject.activate_user(invalid_feature, stub(:id => 42)) }.to raise_error("Invalid feature")
          end
        end

        describe "for the default all group" do
          it "should raise error" do
            expect { subject.activate_group(invalid_feature, :all) }.to raise_error("Invalid feature")
          end
        end

        describe "for a group" do
          before :each do
            subject.define_group(:fivesonly) { |user| user.id == 5 }
          end

          it "should raise error" do
            expect { subject.activate_group(invalid_feature, :fivesonly) }.to raise_error("Invalid feature")
          end
        end

        describe "for a percentage of users" do
          it "should raise error" do
            expect { subject.activate_percentage(invalid_feature, 20) }.to raise_error("Invalid feature")
          end
        end

      end

      describe "attempting to deactivate" do

        describe "for a specific user" do
          it "should raise error" do
            expect { subject.deactivate_user(invalid_feature, stub(:id => 42)) }.to raise_error("Invalid feature")
          end
        end

        describe "for the default all group" do
          it "should raise error" do
            expect { subject.deactivate_group(invalid_feature, :all) }.to raise_error("Invalid feature")
          end
        end

        describe "for a group" do
          before :each do
            subject.define_group(:fivesonly) { |user| user.id == 5 }
          end

          it "should raise error" do
            expect { subject.deactivate_group(invalid_feature, :fivesonly) }.to raise_error("Invalid feature")
          end
        end

        describe "for a percentage of users" do
          it "should raise error" do
            expect { subject.deactivate_percentage(invalid_feature) }.to raise_error("Invalid feature")
          end
        end

        describe "a feature completely" do
          it "should raise error" do
            expect { subject.deactivate_all(invalid_feature) }.to raise_error("Invalid feature")
          end
        end

      end
    end

  end
end
