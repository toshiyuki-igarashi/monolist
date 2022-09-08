class CreateItems < ActiveRecord::Migration[6.1]
  def change
    create_table :items do |t|
      t.string :code
      t.string :name
      t.string :url
      t.string :image_url
      t.string :catch_cpy
      t.text :caption
      t.integer :price

      t.timestamps
    end
  end
end
