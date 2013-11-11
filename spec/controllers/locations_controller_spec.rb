require 'spec_helper'

describe LocationsController do
  before do
    @location = create(:location)
  end
  
  describe "permissions" do
    context "a user that is not logged in" do
      it "should not be able to create a new location" do
        get :new
        response.should redirect_to(new_user_session_path)
      end

      it "should not be able to edit a location" do
        get :edit, {id: @location.id}
        response.should redirect_to(new_user_session_path)
      end

      it "should not be able to delete a location" do
        delete :destroy, {id: @location.id}
        response.should redirect_to(new_user_session_path)
      end
    end

    context "a user that is logged in" do
      before do
        @user = create(:user)
        sign_in @user
      end

      context "when rendering views" do
        render_views

        it "can see all the locations" do
          create(:location, name: 'Ultimate Location')
          get :index

          response.should be_success
          response.body.should include('Ultimate Location')
        end
      end

      it "should be able to create a new location" do
        get :new
        response.should be_success

        chapter = create(:chapter)
        location_params = {
          name: "Fabulous Location",
          address_1: "123 Awesome Lane",
          city: "Awesome Town",
          chapter_id: chapter.id
        }

        expect { post :create, location: location_params }.to change(Location, :count).by(1)
        Location.last.chapter.should == chapter
      end

      it "should be able to edit an location" do
        get :edit, {:id => @location.id}
        response.should be_success
        
        put :update, {:id => @location.id}
        response.should redirect_to(location_path(@location))
      end

      describe "#destroy" do
        it "can delete a location that belongs to no events" do
          expect {
            delete :destroy, {id: @location.id}
          }.to change(Location, :count).by(-1)
        end

        it "cannot delete a location that belongs to an event" do
          create(:event, location: @location)
          expect {
            delete :destroy, {id: @location.id}
          }.not_to change(Location, :count)
        end
      end
    end
  end
end