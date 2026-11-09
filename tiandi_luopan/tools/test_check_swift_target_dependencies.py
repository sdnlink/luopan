"""Regression coverage for project errors that prevent xcodebuild from opening it."""
import unittest

from check_swift_target_dependencies import PROJECT, source_phases, validate_project_structure


PROJECT_FIXTURE = """
{
    objects = {
        1001 /* Source */ = {isa = PBXBuildFile; fileRef = 2001 /* Source */; };
        2001 /* Source */ = {isa = PBXFileReference; path = Example.swift; };
        2002 /* ja */ = {isa = PBXFileReference; path = ja.lproj/InfoPlist.strings; };
        4001 /* App */ = {
            isa = PBXGroup;
            children = (2001 /* Source */, 4002 /* Localized */ ,);
        };
        4002 /* Localized */ = {
            isa = PBXVariantGroup;
            children = (2002 /* ja */,);
        };
    };
}
"""


class ProjectStructureTests(unittest.TestCase):
    def test_checked_in_project_has_unique_objects_and_group_membership(self):
        validate_project_structure(PROJECT.read_text(encoding="utf-8"))

    def test_valid_source_and_localized_resource_keep_distinct_ids(self):
        validate_project_structure(PROJECT_FIXTURE)

    def test_new_source_cannot_reuse_a_localized_resource_id(self):
        duplicate = PROJECT_FIXTURE.replace(
            '    objects = {',
            '    objects = {\n        2002 /* New source */ = {isa = PBXFileReference; path = New.swift; };')
        with self.assertRaisesRegex(ValueError, "Duplicate Xcode object ID 2002"):
            validate_project_structure(duplicate)

    def test_ids_are_unique_across_object_kinds(self):
        duplicate = PROJECT_FIXTURE.replace(
            '    objects = {',
            '    objects = {\n        2001 = {isa = PBXBuildFile; fileRef = 2002; };')
        with self.assertRaisesRegex(ValueError, "Duplicate Xcode object ID 2001"):
            validate_project_structure(duplicate)

    def test_source_checks_reject_duplicates_before_dictionary_conversion(self):
        duplicate = PROJECT_FIXTURE.replace('2002 /* ja */ =', '2001 /* ja */ =')
        with self.assertRaisesRegex(ValueError, "Duplicate Xcode object ID 2001"):
            source_phases(duplicate)

    def test_file_cannot_belong_to_both_regular_and_localized_group(self):
        duplicate = PROJECT_FIXTURE.replace('children = (2002', 'children = (2001 /* Source */, 2002')
        with self.assertRaisesRegex(ValueError, "2001 is a child of multiple groups: 4001 and 4002"):
            validate_project_structure(duplicate)

    def test_group_cannot_repeat_the_same_child(self):
        duplicate = PROJECT_FIXTURE.replace('children = (2001', 'children = (2001 /* Source */, 2001')
        with self.assertRaisesRegex(ValueError, "2001 is a child of multiple groups: 4001 and 4001"):
            validate_project_structure(duplicate)

    def test_group_child_must_exist(self):
        missing = PROJECT_FIXTURE.replace('children = (2002', 'children = (9999')
        with self.assertRaisesRegex(ValueError, "Group 4002 references missing child 9999"):
            validate_project_structure(missing)

    def test_build_file_reference_must_exist(self):
        missing = PROJECT_FIXTURE.replace('fileRef = 2001', 'fileRef = 9999')
        with self.assertRaisesRegex(ValueError, "Build file 1001 references missing file 9999"):
            validate_project_structure(missing)

    def test_empty_project_cannot_pass(self):
        with self.assertRaisesRegex(ValueError, "No Xcode object definitions found"):
            validate_project_structure('{}')


if __name__ == "__main__":
    unittest.main()
