class Serie < Airrecord::Table
  self.base_key = 'app9kWZ1eEhSFtmDs'
  self.table_name = 'Series'

  # Create a Book record from a Goodreads API request
  def create_from_goodreads(series)
    self['Title'] = series.title
    self.save
  end
end
