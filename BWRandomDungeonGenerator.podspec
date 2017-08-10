Pod::Spec.new do |spec|
	spec.name             = 'BWRandomDungeonGenerator'
	spec.version          = '1.0.0'
	spec.license          = { :type => 'BSD' }
	spec.homepage         = 'https://github.com/bitwit/swift-random-dungeon-generator'
	spec.authors          = { 'Kyle Newsome' => 'kyle@bitwit.ca' }
	spec.summary          = 'A random dungeon generator written in Swift with no closed source dependencies'
	spec.source           = { :git => 'https://github.com/bitwit/swift-random-dungeon-generator.git', :tag => '1.0.0' }
	spec.source_files     = 'Source/**.swift'
	spec.requires_arc     = true
	spec.social_media_url = "https://twitter.com/kylnew"
end
