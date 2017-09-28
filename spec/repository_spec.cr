require "pg"
require "./spec_helper"

db = DB.open(ENV["DATABASE_URL"] || raise "No DATABASE_URL is set!")
query_logger = Core::QueryLogger.new(nil)

describe Repo do
  user_repo = Repo(User).new(db, query_logger)
  post_repo = Repo(Post).new(db, query_logger)

  user_created_at = uninitialized Time

  describe "#insert" do
    user = User.new(name: "Test User")
    result = user_repo.insert(user)
    query = Query(User).last

    it "sets created_at field" do
      user_created_at = db.scalar(query.select(:created_at).to_s).as(Time)
      user_created_at.should be_truthy
    end

    it "doesn't set updated_at field" do
      db.scalar(query.select(:updated_at).to_s).as(Time?).should be_nil
    end

    it "works with references" do
      # TODO: Replace with insert result
      user.id = db.scalar(query.select(:id).to_s).as(Int32)

      post = Post.new(author: user, content: "Some content")
      post_repo.insert(post).should be_truthy
    end

    pending "returns fresh id" do
      previous_id = db.scalar(query.select(:id).to_s).as(Int32)
      user_repo.insert(user).should eq(previous_id + 1)
    end
  end

  describe "#query" do
    complex_query = Query(User)
      .select(:*, :"COUNT (posts.id) AS posts_count")
      .join(:posts)
      .group_by(:"users.id", :"posts.id")
      .order_by(:"users.id DESC")
      .limit(1)

    user = user_repo.query(complex_query).first

    it "returns a valid instance" do
      user.id.should be_a(Int32)
      user.role.should eq(User::Role::User)
      user.name.should eq("Test User")
      user.posts_count.should be_a(Int64)
      user.created_at.should be_a(Time)
      user.updated_at.should eq(nil)
    end

    pending "handles DB errors" do
      expect_raises do
        user_repo.query("INVALID QUERY")
      end
    end
  end

  describe "#update" do
    user = user_repo.query(Query(User).last).first

    it "ignores empty changes" do
      user_repo.update(user).should eq nil
    end

    pending "handles DB errors" do
      user.id = nil
      expect_raises do
        user_repo.update(user)
      end
    end

    user.name = "Updated User"
    update = user_repo.update(user)
    updated_user = user_repo.query(Query(User).last).first

    it "actually updates" do
      updated_user.name.should eq "Updated User"
    end

    pending "returns an amount of affected rows" do
      update.should eq(1)
    end
  end

  describe "#delete" do
    post = post_repo.query(Query(Post).last).first
    post_id = post.id
    delete = post_repo.delete(post)

    it do
      delete.should be_truthy
      post_repo.query(Query(Post)[post_id]).empty?.should eq true
    end

    pending "returns an amount of affected rows" do
      delete.should eq(1)
    end

    pending "handles DB errors" do
      # It's already deleted, so
      expect_raises do
        post_repo.delete(post)
      end
    end
  end
end
