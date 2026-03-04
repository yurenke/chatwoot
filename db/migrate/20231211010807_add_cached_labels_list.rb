# class AddCachedLabelsList < ActiveRecord::Migration[7.0]
#   def change
#     add_column :conversations, :cached_label_list, :string
#     Conversation.reset_column_information
#     ActsAsTaggableOn::Taggable::Cache.included(Conversation)
#   end
# end
class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!  # 允許 concurrent index

  def up
    add_column :conversations, :cached_label_list, :string

    Conversation.reset_column_information

    Conversation.find_each do |conversation|
      conversation.update_column(:cached_label_list, conversation.label_list.join(', '))
    end
  end

  def down
    remove_column :conversations, :cached_label_list
  end
end