require 'spec_helper'

describe RsvpsController do
  def extract_rsvp_params(rsvp)
    accessible_attrs = Rsvp.attr_accessible[:default].map(&:to_s) + ['role_id']
    rsvp.attributes.select { |attr, val| accessible_attrs.include?(attr) }
  end

  before do
    @event = create(:event, title: 'The Best Railsbridge')
  end

  describe "when signed in" do
    before do
      @user = create(:user)
      sign_in @user
    end

    describe "#volunteer" do
      it "creates an RSVP for the volunteer role" do
        get :volunteer, event_id: @event.id
        assigns(:rsvp).role.should == Role::VOLUNTEER
      end

      describe "when the user has previously volunteered" do
        before do
          old_event = create(:event)
          @old_rsvp = create(:rsvp,
                 user: @user,
                 event: old_event,
                 subject_experience: 'I have made many websites',
                 teaching_experience: 'I have taught many websites',
                 job_details: 'Software Engineer'
          )
        end

        it "creates a new RSVP with detail sfrom their previous RSVPs" do
          get :volunteer, event_id: @event.id
          assigns(:rsvp).subject_experience.should == @old_rsvp.subject_experience
          assigns(:rsvp).teaching_experience.should == @old_rsvp.teaching_experience
          assigns(:rsvp).job_details.should == @old_rsvp.job_details
        end
      end
    end

    describe "#learn" do
      it "creates an RSVP for the student role" do
        get :learn, event_id: @event.id
        assigns(:rsvp).role.should == Role::STUDENT
      end
    end

    describe "when there is an existing RSVP for this user" do
      before do
        @rsvp = create(:rsvp, user: @user, event: @event)
      end

      it 'redirects to the event page when trying to create a new RSVP' do
        get :volunteer, event_id: @event.id
        response.should redirect_to(@event)

        get :learn, event_id: @event.id
        response.should redirect_to(@event)
      end
    end
  end

  describe "#create" do
    before do
      @rsvp_params = extract_rsvp_params build(:rsvp, event: @event)
    end

    context "when not logged in" do
      it "redirects to the sign in page" do
        assigns[:current_user].should be_nil
        post :create, event_id: @event.id, rsvp: @rsvp_params
        response.should redirect_to("/users/sign_in")
      end

      it "does not create any new rsvps" do
        expect {
          post :create, event_id: @event.id, rsvp: @rsvp_params
        }.to_not change { Rsvp.count }
      end
    end

    context "when there is no rsvp for the volunteer/event" do
      before do
        @user = create(:user)
        sign_in @user
        @rsvp_params = extract_rsvp_params build(:rsvp, event: @event)
      end

      def do_request
        post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
      end
      
      it "should allow the user to newly volunteer for an event" do
        expect { do_request }.to change { Rsvp.count }.by(1)
      end

      it "redirects to the event page related to the rsvp with flash confirmation" do
        do_request
        response.should redirect_to(event_path(@event))
        flash[:notice].should match(/thanks/i)
      end

      it "should create a rsvp that persists and is valid" do
        do_request
        assigns[:rsvp].should be_persisted
        assigns[:rsvp].should be_valid
      end

      it "should set the new rsvp with the selected event, and current user" do
        do_request
        assigns[:rsvp].user_id.should == assigns[:current_user].id
        assigns[:rsvp].event_id.should == @event.id
      end

      it "should update the user's gender" do
        do_request
        expect(@user.reload.gender).to eq("human")
      end

      context "when the event is not full" do
        before do
          @event.update_attribute(:student_rsvp_limit, 2)
          create(:volunteer_rsvp, event: @event)
          create(:volunteer_rsvp, event: @event)
          create(:student_rsvp, event: @event)
        end

        describe "and a student rsvps" do
          before do
            @rsvp_params = extract_rsvp_params build(:student_rsvp, event: @event)
            expect {
              post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
            }.to change(Rsvp, :count).by(1)
          end

          it "adds the a newly rsvp'd student as a confirmed user" do
            Rsvp.last.waitlist_position.should be_nil
          end

          it "gives a notice that does not mention the waitlist" do
            flash[:notice].should_not match(/waitlist/i)
          end
        end
      end

      describe "session attendance" do
        context "when there is only one session" do
          it 'assigns the user to the session' do
            expect { do_request }.to change(Rsvp, :count).by(1)
            Rsvp.last.event_sessions.tap do |sessions|
              sessions.count.should == 1
              sessions.map(&:id).should == @event.event_sessions.map(&:id)
            end
          end
        end

        context "when there are multiple sessions" do
          before do
            create(:event_session, event: @event)
            create(:event_session, event: @event, required_for_students: false)
            @event.reload
          end

          context "a student" do
            before do
              @rsvp_params = extract_rsvp_params build(:student_rsvp, event: @event)
            end

            it 'is assigned as attending all required sessions' do
              expect { do_request }.to change(Rsvp, :count).by(1)
              Rsvp.last.event_sessions.tap do |sessions|
                sessions.count.should == 2
                sessions.map(&:id).should == @event.event_sessions.where(required_for_students: true).pluck(:id)
              end
            end
          end

          context "a volunteer" do
            before do
              @rsvp_params[:event_session_ids] = [@event.event_sessions.first.id]
            end

            it 'is assigned as attending only the desired sessions' do
              expect { do_request }.to change(Rsvp, :count).by(1)
              Rsvp.last.event_sessions do |sessions|
                sessions.count.should == 1
                sessions.map(&:id).should == @event.event_sessions.map(&:id)
              end
            end
          end
        end
      end

      context "when the event is full of students" do
        before do
          @event.update_attribute(:student_rsvp_limit, 2)
          create(:student_rsvp, event: @event)
          create(:student_rsvp, event: @event)
        end

        describe "and a student rsvps" do
          before do
            @rsvp_params = extract_rsvp_params build(:student_rsvp, event: @event, role: Role::STUDENT)
            expect {
              post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
            }.to change(Rsvp, :count).by(1)
          end

          it "adds the student to the waitlist" do
            Rsvp.last.waitlist_position.should == 1
          end

          it "gives a notice that mentions the waitlist" do
            flash[:notice].should match(/waitlist/i)
          end

          describe "then another student rsvps" do
            before do
              sign_out @user
              sign_in create(:user)

              expect {
                post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
              }.to change(Rsvp, :count).by(1)
            end

            it "adds the student the waitlist after the original student" do
              Rsvp.last.waitlist_position.should == 2
            end
          end
        end

        describe "and a volunteer rsvps" do
          before do
            @rsvp_params = extract_rsvp_params build(:volunteer_rsvp, event: @event, role: Role::VOLUNTEER)
          end

          it "adds the volunteer as confirmed" do
            expect {
              post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
            }.to change(Rsvp, :count).by(1)
            Rsvp.last.waitlist_position.should be_nil
          end
        end
      end

      describe "childcare information" do
        context "when childcare_needed is unchecked" do
          before do
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '0', childcare_info: 'goodbye, cruel world'), user: { gender: "human" }
          end

          it "should clear childcare_info" do
            assigns[:rsvp].childcare_info.should be_blank
          end
        end

        context "when childcare_needed is checked" do
          it "should has validation errors for blank childcare_info" do
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '1', childcare_info: '')
            assigns[:rsvp].should have(1).errors_on(:childcare_info)
          end

          it "updates sets childcare_info when not blank" do
            child_info = "Johnnie Kiddo, 7\nJane Kidderino, 45"
            post :create, event_id: @event.id, rsvp: @rsvp_params.merge(
              needs_childcare: '1',
              childcare_info: child_info
            ), user: { gender: "human" }
            assigns[:rsvp].childcare_info.should == child_info
          end
        end
      end

      describe "dietary restriction information" do
        context "when a dietary restriction is checked" do
          it "adds a dietary restriction" do
            expect {
              post :create, event_id: @event.id, rsvp: @rsvp_params,
                   dietary_restrictions: { vegan: "1" }, user: { gender: "human" }
            }.to change { DietaryRestriction.count }.by(1)

            Rsvp.last.dietary_restrictions.map(&:restriction).should == ["vegan"]
          end
        end
      end
    end

    context "when there is already a rsvp for the volunteer/event" do
      #the user may have canceled, changed his/her mind, and decided to volunteer again
      before do
        @user = create(:user)
        sign_in @user
        @rsvp = create(:rsvp, user: @user, event: @event)
        @rsvp_params = extract_rsvp_params @rsvp
      end

      it "does not create any new rsvps" do
        expect {
          post :create, event_id: @event.id, rsvp: @rsvp_params, user: { gender: "human" }
        }.to_not change { Rsvp.count }
      end
    end
  end

  describe "#update" do
    before do
      @user = create(:user)
      @other_user = create(:user)
      @my_rsvp = create(:rsvp, user: @user, event: @event)
      @other_rsvp = create(:rsvp, user: @other_user, event: @event)

      sign_in @user
    end

    it 'updates rsvps owned by the logged in user' do
      put :update, event_id: @event.id, id: @my_rsvp.id, rsvp: {subject_experience: 'Abracadabra'}, user: { gender: "human" }
      response.should redirect_to(@event)
      @my_rsvp.reload.subject_experience.should == 'Abracadabra'
    end

    it 'does not update rsvps owned by other users' do
      put :update, event_id: @event.id, id: @other_rsvp.id, rsvp: {subject_experience: 'Abracadabra'}, user: { gender: "human" }
      response.should_not be_success
      @other_rsvp.reload.subject_experience.should_not == 'Abracadabra'
    end
  end

  describe "#destroy" do
    before do
      @user = create(:user)
      sign_in @user
    end

    context "when there is an existing rsvp" do
      before do
        @rsvp = create(:rsvp, user: @user)
      end

      it "should destroy the rsvp" do
        expect {
          delete :destroy, event_id: @rsvp.event.id, id: @rsvp.id
        }.to change { Rsvp.count }.by(-1)

        expect {
          @rsvp.reload
        }.to raise_error(ActiveRecord::RecordNotFound)

        flash[:notice].should match(/no longer signed up/i)
      end

      it "should reorder the waitlist" do
        Event.should_receive(:find_by_id).and_return(@rsvp.event)
        @rsvp.event.should_receive(:reorder_waitlist!)
        delete :destroy, event_id: @rsvp.event.id, id: @rsvp.id
      end
    end

    context "when there is no RSVP for this user" do
      it "should notify the user s/he has not signed up to volunteer for the event" do
        expect {
          delete :destroy, event_id: 3298423, id: 29101
        }.to change { Rsvp.count }.by(0)
        flash[:notice].should match(/You are not signed up/i)
      end
    end
  end
end
