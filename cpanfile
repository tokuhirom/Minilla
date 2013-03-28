on test => sub {
    requires 'Test::More', 0.98;
};

on configure => sub {
    requires 'Module::Build', 0.40;
    requires 'Module::CPANfile', 0.9008; # merge_meta
};

on 'develop' => sub {
};

