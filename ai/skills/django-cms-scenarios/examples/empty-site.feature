Feature: A site before its first page
  As the owner of the site
  I want a site with no page to welcome its editors and to send its visitors to the login page
  So that a build that came out broken is caught before the first page is written

  # For a site as the builder leaves it. Once the site has a home page, these scenarios are the
  # ones to replace.

  Scenario: A logged in user gets the welcome screen and the toolbar
    Given I am a logged in user with the "admin" user
    When I go to the homepage
    Then I should see the welcome screen
    And I should see the toolbar
    And the toolbar should have the "Create" button
    But the toolbar should not have the "Page" menu

  Scenario: The wizard offers a new page
    Given I am a logged in user with the "editor" user
    When I go to the homepage
    And I open the create wizard
    Then the create wizard should offer "New page"

  Scenario: The page tree lists no page
    Given I am a logged in user with the "editor" user
    And I am on the page tree
    Then I should see the page tree
    But I should not see "A page written by a scenario" in the page tree

  Scenario: A visitor is sent to the login page, and an address with no page is not found
    Given I am not logged in
    When I go to the homepage
    Then I should see the login form
    And I should not see the toolbar
    When I go to "/en/this-page-does-not-exist/"
    Then I should be on the page not found page
