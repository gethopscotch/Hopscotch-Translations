namespace :gengo do
  desc "Show how many translations are needed"
  task number_of_translations_needed: :environment do
    language_jobs = build_jobs
    num_translations = 0
    index = 0
    language_jobs.each do |jobs|
      num_translations += jobs.count
      language = LANGUAGES[index]
      puts "translation needed for #{jobs.count} jobs for #{language}"
      index += 1
    end
    puts "translation needed for #{num_translations} total"
  end

  desc "Order translations"
  task translate: :environment do
    translate
  end

  desc "view all orders"
  task view_orders: :environment do
    view_orders
  end

  desc "Update or create jobs for all orders"
  task sync_jobs_with_gengo: :environment do
    sync_jobs_with_gengo
  end

  desc "Sync words with complete jobs"
  task sync_translations_with_jobs: :environment do
    sync_translations_with_jobs
  end

  # desc "sync local jobs with translations"
  # task sync_local_jobs_with_translations: :environment do
    # sync_local_jobs_with_translations
  # end
  #
  desc "Resync foreign words"
  task pull_translations_for_untranslated_foreign_words: :environment do
    ForeignWord.untranslated.each do |word|
      job = word.gengo_job
      job.try(:sync_with_foreign_word, gengo_for_env)
    end

  end


  desc "Make sure all gengo jobs actually set the translated string on foreign words"
  task resync_all: :environment do
    GengoJob.approved.latest_week.each do |job|
      job.sync_with_gengo_and_foreign_word(gengo_for_env)
    end
  end

  desc "Sync with gengo then sync with db then translate"
  task sync_all: :environment do
    sync_jobs_with_gengo
    sync_translations_with_jobs
  end
end

def gengo_for_env
  if Rails.env.production?
    GENGO
  else
    GENGO_SANDBOX
  end
end

def translate
  gengo = gengo_for_env
  language_jobs = build_jobs
  language_jobs.each do |jobs|
    resp = gengo.postTranslationJobs({jobs: jobs, as_group: 1})
    order_id = resp["response"]["order_id"]
    job_count = resp["response"]["job_count"]
    order = GengoOrder.create(order_id: order_id, available_job_count: job_count)
    puts "translated #{jobs.count} jobs"
  end
end

def sync_local_jobs_with_translations
  gengo = gengo_for_env
  jobs = GengoJob.approved.locally_unsynced
  jobs.each do |gengo_job|
    gengo_job.sync_with_foreign_word(gengo)
  end
end

def sync_translations_with_jobs
  gengo = gengo_for_env

  jobs = GengoJob.unsynced
  jobs.each do |gengo_job|
    gengo_job.sync_with_gengo_and_foreign_word(gengo)
  end
end

def sync_jobs_with_gengo
  gengo = gengo_for_env
  orders = GengoOrder.all
  orders.each do |gengo_order|
    gengo_order.create_jobs_from_gengo(gengo)
  end
end

def build_jobs
  jobs = LANGUAGES.map{ |language| build_job_for_language(language) }
  jobs.compact
end

def build_job_for_language(language)
  jobs = {}

  ForeignWord.untranslated.where(language: language).each_with_index do |foreign_word, index|
    next unless foreign_word.needs_translation_job?

    hash = foreign_word.gengo_hash
    jobs["job_#{index + 1}"]  = hash
  end

  puts "#{language} #{jobs.count}"
  jobs.empty? ? nil : jobs
end

def view_orders
  gengo = gengo_for_env
  orders = GengoOrder.all

  orders.each do |gengo_order|
    resp = gengo.getTranslationOrderJobs(order_id: gengo_order.order_id)
    puts resp["response"]["order"]
  end
end



