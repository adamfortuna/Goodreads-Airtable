class Shelf < Airrecord::Table
  self.base_key = 'app9kWZ1eEhSFtmDs'
  self.table_name = 'Shelves'

  # Create a Book record from a Goodreads API request
  def create_from_goodreads(shelf)
    self['Name'] = shelf.name
    self.save
  end
end
