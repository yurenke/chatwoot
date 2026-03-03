class MessagePolicy < ApplicationPolicy
  def update?
    record.editable_by?(user)
  end
  def edit?
    update?
  end
end