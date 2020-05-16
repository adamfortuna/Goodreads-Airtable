class Author < Airrecord::Table
  self.base_key = 'app9kWZ1eEhSFtmDs'
  self.table_name = 'Authors'

  def create_from_goodreads(author)
    self['Name'] = author.name
    self.save
  end
end
