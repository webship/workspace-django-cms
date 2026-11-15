Feature: An editor writes a page and removes it again
  As an editor
  I want to create, publish, unpublish and delete a page
  So that the suite proves the editor works and leaves the site as it found it

  # On a site with no page, the first page becomes the home page: this scenario deletes it again,
  # so the site is empty for the next feature.

  Scenario: The editor publishes a page, a visitor reads it, and the editor deletes it
    Given I am a logged in user with the "editor" user
    When I go to the homepage
    And I create a page titled "A page written by a scenario" with the text "This page is written and removed by the suite." with the wizard
    Then I should be in edit mode
    And the page version should be "Draft"
    And the "Page Content" placeholder should have 1 plugin
    When I publish the page
    Then the page version should be "Published"
    And I should not be in edit mode
    And I should see "This page is written and removed by the suite."
    When I log out
    And I go to the homepage
    Then the response status code should be 200
    And I should see "This page is written and removed by the suite."
    And the navigation menu should list "A page written by a scenario"
    And I should not see the toolbar
    Given I am a logged in user with the "editor" user
    And I am on the page tree
    Then the page "A page written by a scenario" should be published in the page tree
    When I unpublish the page "A page written by a scenario" in the page tree
    And I delete the page "A page written by a scenario" in the page tree
    Then I should not see "A page written by a scenario" in the page tree
