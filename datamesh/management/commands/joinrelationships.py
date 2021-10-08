from django.core.management.base import BaseCommand
from datamesh.management.commands.product import product_product_tool_relationship, product_product_team_relationship
from datamesh.management.commands.producttool import product_tool_users_relationship



class Command(BaseCommand):

    def add_arguments(self, parser):
        """Add --file argument to Command."""
        parser.add_argument(
            '--file', default=None, nargs='?', help='Path of file to import.',
        )

    def handle(self, *args, **options):
        run_seed(self, options['file'])


def run_seed(self, mode):
    """call function here."""

    """product"""
    product_product_team_relationship()
    product_product_tool_relationship()

    """product tool"""
    product_tool_users_relationship()



