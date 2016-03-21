require 'pry'
require 'ipaddr'
require 'io/console'
require 'headless'
require 'nokogiri'
require 'selenium/webdriver'

APP_NAME = 'NatEditor'.freeze
PROTOCOLS = %w(TCP UDP ESP AH tcp udp esp ah).freeze

$headless = nil
$driver = nil

module NatEditor
  @addr = ''
  @nat = []

  def self.login
    print "RV-S340NE (192.168.1.1): "
    @addr = STDIN.gets.chomp
    @addr = "192.168.1.1" if @addr.empty?

    # print "user (user): "
    # user = STDIN.gets.chomp
    # user = "user" if user.empty?
    user = 'user' # RV-S340NEはユーザ名変更不可

    print "Password: "
    pass = STDIN.noecho(&:gets).tap{puts}
    pass.chomp!

    print 'Please wait... '
    $headless = Headless.new
    $headless.start
    $driver = Selenium::WebDriver.for :firefox
    $driver.get "http://#{user}:#{pass}@#{@addr}/"
    $driver.get "http://#{@addr}/index.cgi/ipnat_main"
    reload
  rescue StandardError
    puts 'login failed'
    $driver.close unless $driver.nil?
    $headless.destroy unless $headless.nil?
    puts 'Please retry login'
    # puts ex.backtrace.first + ": #{ex.message} (#{ex.class})"
    # ex.backtrace[1..-1].each { |m| puts "\tfrom #{m}" }
  end

  def self.login?
    return true unless $driver.nil?
    puts "You need to login. Please input 'login'"
    return false
  end

  def self.valid_num?(n)
    return true if n.between?(1, 50)
    puts 'Specify a number from 1 to 50'
    return false
  end

  def self.valid_ip?(str)
    IPAddr.new(str) ? true : false rescue false
  end

  def self.valid_params?(available, prot, port, host)
    unless available == 'true' || available == 'false'
      puts "Specify 'true' or 'false' to available"
      return false
    end
    unless PROTOCOLS.any? { |p| p == prot }
      puts 'Invalid Protocol (tcp,udp,esp,ah)'
      return false
    end
    if (prot.upcase == 'ESP' || prot.upcase == 'AH')
      unless port == '-'
        puts "Input '-' when ESP or AH protocol"
        return false
      end
    else
      unless port.to_i.between?(1, 65535)
        puts 'Invalid Port (1-65535)'
        return false
      end
    end
    unless valid_ip?(host)
      puts 'Invalid IP Address'
      return false
    end
    return true
  end

  def self.print_entry
    return unless login?

    puts 'num avail  prot port   host             num avail  prot port   host'
    (0..24).each do |i|
      left_side = "#{(i + 1).to_s.rjust(2,' ')}  #{@nat[i][0].ljust(7,' ')}#{@nat[i][1].ljust(5,' ')}#{@nat[i][2].ljust(7,' ')}#{@nat[i][3].ljust(17,' ')}"
      j = i + 25
      right_side = "#{(j + 1).to_s.rjust(2,' ')}  #{@nat[j][0].ljust(7,' ')}#{@nat[j][1].ljust(5,' ')}#{@nat[j][2].ljust(7,' ')}#{@nat[j][3].ljust(17,' ')}"
      puts "#{left_side}#{right_side}"
    end
    return
  end

  def self.entry(n)
    return unless login?

    n = n.to_i
    return unless valid_num?(n)

    ent = @nat[n - 1]

    puts 'num avail  prot port   host'
    puts "#{(n).to_s.rjust(2,' ')}  #{ent[0].ljust(7,' ')}#{ent[1].ljust(5,' ')}#{ent[2].ljust(7,' ')}#{ent[3].ljust(17,' ')}"
  end

  def self.set_entry(num, available, prot, port, host)
    return unless login?

    n = num.to_i
    return unless valid_num?(n)

    return unless valid_params?(available, prot, port, host)

    prot.upcase!
    port = "―" if (prot == 'ESP' || prot == 'AH')

    puts "Set #{num}"
    entry(n)
    puts '->'
    puts "#{(n).to_s.rjust(2,' ')}  #{available.ljust(7,' ')}#{prot.ljust(5,' ')}#{port.ljust(7,' ')}#{host.ljust(17,' ')}"

    print 'Are you sure? [yN] '
    input = STDIN.gets.chomp

    if input == 'y'
      ent_num = ((n - 1) % 16) + 2
      tab_num = ((n - 1) / 16) + 1
      $driver.get "http://#{@addr}/index.cgi/ipnat_main"
      if tab_num > 1
        tab = $driver.find_elements(xpath: "//*[@id='tab1']/table[3]/tbody/tr/td/a[#{tab_num - 1}]")[0]
        tab.click
      end

      after_toggle = false
      # エントリが既に有効な場合はこのタイミングでチェック状態を取得できる
      check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{n}']")[0]
      if check.selected?.to_s != available
        check.click
        update = $driver.find_elements(xpath: "//*[@id='EXTEND_BUTTON_#{tab_num}']")[0]
        update.click

        # エントリが無効な状態から設定した場合にはチェックを有効化する必要あり
        after_toggle = true if available == 'true'
      end

      edit = $driver.find_elements(xpath: "//*[@id='tab#{tab_num}']/table[2]/tbody/tr[#{ent_num}]/td[6]/a")[0]
      edit.click

      prot_field = $driver.find_elements(id: 'PROTOCOL_TYPE')[0]
      option = Selenium::WebDriver::Support::Select.new(prot_field)
      option.select_by(:value, prot.downcase)

      unless (prot == 'ESP' || prot == 'AH')
        port_field = $driver.find_elements(id: 'PORT_NUMBER')[0]
        port_field.clear
        port_field.send_keys(port)
      end

      host_field = $driver.find_elements(id: 'LAN_HOST')[0]
      host_field.clear
      host_field.send_keys(host)

      update = $driver.find_elements(id: 'UPDATE_BUTTON')[0]
      update.click

      save = $driver.find_elements(id: 'SAVE_BUTTON')[0]
      save.click

      back = $driver.find_elements(xpath: '//*[@id="main_form"]/div[4]/input[2]')[0]
      back.click

      if after_toggle
        check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{n}']")[0]
        check.click
        update = $driver.find_elements(xpath: "//*[@id='EXTEND_BUTTON_#{tab_num}']")[0]
        update.click
      end

      check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{n}']")[0]
      result = check.selected?.to_s
      store_entry(n, result, prot, port, host)

      puts "Success"
    else
      puts 'abort'
    end
  end

  def self.toggle_entry(n)
    return unless login?

    n = n.to_i
    return unless valid_num?(n)

    tab_num = ((n - 1) / 16) + 1

    before = @nat[n - 1][0]
    if before == 'true'
      after = 'false'
    elsif before == 'false'
      after = 'true'
    else
      puts "Can't toggle. #{n} is empty"
      return
    end

    puts "Toggle #{n} #{before} -> #{after}"
    print 'Are you sure? [yN] '
    input = STDIN.gets.chomp

    if input == 'y'
      $driver.get "http://#{@addr}/index.cgi/ipnat_main"
      if tab_num > 1
        tab = $driver.find_elements(xpath: "//*[@id='tab1']/table[3]/tbody/tr/td/a[#{tab_num - 1}]")[0]
        tab.click
      end

      del = $driver.find_elements(xpath: "//*[@id='ENTRY_DEL_#{n}']")[0]
      if del.nil?
        puts "Can't toggle. #{n} is empty"
        return
      end

      check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{n}']")[0]
      check.click

      update = $driver.find_elements(xpath: "//*[@id='EXTEND_BUTTON_#{tab_num}']")[0]
      update.click

      check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{n}']")[0]
      result = check.selected?.to_s
      @nat[n - 1][0] = result
      puts "Failed. Please retry toggle" unless before != result
    else
      puts 'abort'
    end
    puts "Success"
  end

  def self.delete_entry(n)
    return unless login?

    n = n.to_i
    return unless valid_num?(n)

    tab_num = ((n - 1) / 16) + 1

    puts "Delete #{n}"
    print 'Are you sure? [yN] '
    input = STDIN.gets.chomp

    if input == 'y'
      $driver.get "http://#{@addr}/index.cgi/ipnat_main"
      if tab_num > 1
        tab = $driver.find_elements(xpath: "//*[@id='tab1']/table[3]/tbody/tr/td/a[#{tab_num - 1}]")[0]
        tab.click
      end

      del = $driver.find_elements(xpath: "//*[@id='ENTRY_DEL_#{n}']")[0]
      unless del.nil?
        del.click
        store_entry(n, '-', '', '', '')
      else
        puts "Can't delete. #{n} is empty"
      end
    else
      puts 'abort'
    end
    puts "Success"
  end

  def self.store_entry(n, available, prot, port, host)
    @nat[n - 1] = [available, prot, port, host]
  end

  def self.load_entry(n, tab, doc)
    num = n - 1 + 16 * (tab - 1)
    check = $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{num}']")[0].selected?.to_s
    check = '-' unless $driver.find_elements(xpath: "//*[@id='ENTRY_CHECK_#{num}']")[0].enabled?
    prot = doc.xpath("//*[@id='tab#{tab}']/table[2]/tbody/tr[#{n}]/td[2]").text.gsub(/[[:blank:]]/, '')
    port = doc.xpath("//*[@id='tab#{tab}']/table[2]/tbody/tr[#{n}]/td[3]").text.gsub(/[[:blank:]]/, '')
    host = doc.xpath("//*[@id='tab#{tab}']/table[2]/tbody/tr[#{n}]/td[4]").text.gsub(/[[:blank:]]/, '')
    # 値に全角スペースが含まれるためそれも含めて除去                                   gsub(/[[:blank:]]/,'')
    store_entry(num, check, prot, port, host)
  end

  def self.reload
    return unless login?

    $driver.get "http://#{@addr}/index.cgi/ipnat_main"
    doc = Nokogiri::HTML($driver.page_source)

    (1..16).each { |n| load_entry(n + 1, 1, doc) }

    tab2 = $driver.find_elements(xpath: '//*[@id="tab1"]/table[3]/tbody/tr/td/a[1]')[0]
    tab2.click
    (17..32).each { |n| load_entry(n - 15, 2, doc) }

    tab3 = $driver.find_elements(xpath: '//*[@id="tab2"]/table[3]/tbody/tr/td/a[2]')[0]
    tab3.click
    (33..48).each { |n| load_entry(n - 31, 3, doc) }

    tab4 = $driver.find_elements(xpath: '//*[@id="tab3"]/table[3]/tbody/tr/td/a[3]')[0]
    tab4.click
    (49..50).each { |n| load_entry(n - 47, 4, doc) }
    return
  end
end

Pry.commands.block_command 'login' do
  output.puts NatEditor.login
end

Pry.commands.block_command 'print' do
  output.puts NatEditor.print_entry
end

Pry.commands.block_command 'get' do |*args|
  args.map { |entry| output.puts NatEditor.entry(entry) }
end

Pry.commands.block_command 'set' do |num, available, prot, port, host|
  output.puts NatEditor.set_entry(num, available, prot, port, host)
end

Pry.commands.block_command 'toggle' do |*args|
  args.map { |entry| output.puts NatEditor.toggle_entry(entry) }
end

Pry.commands.block_command 'del' do |*args|
  args.map { |entry| output.puts NatEditor.delete_entry(entry) }
end

Pry.commands.block_command 'reload' do
  output.puts NatEditor.reload
end

Pry.commands.block_command 'help' do
  output.puts <<-'EOS'
    login  : Connect to your RV-S340NE
    exit   : Disconnect to your RV-S340NE
    print  : Print All NAT entry
    get    : Print specified NAT entry
             > get 10
    set    : Set specified NAT entry
             > set 10 true TCP 8080 192.168.1.10
    toggle : Toggle enable/disable of entry
             > toggle 10
    del    : Delete specified NAT entry
             > del 10
    reload : Reload All NAT entry
  EOS
end

Pry.prompt = [
  proc { "#{APP_NAME}> " },
  proc { "#{APP_NAME}* " }
]

begin
  puts "type 'help' to help. type 'exit' to terminate.\n\n"
  pry
ensure
  $headless.destroy unless $headless.nil?
  $driver.close unless $driver.nil?
end
