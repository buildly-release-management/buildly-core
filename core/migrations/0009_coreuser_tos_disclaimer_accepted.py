# Generated by Django 2.2.28 on 2022-12-22 15:27

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0008_organization_unlimited_free_plan'),
    ]

    operations = [
        migrations.AddField(
            model_name='coreuser',
            name='tos_disclaimer_accepted',
            field=models.BooleanField(default=False),
        ),
    ]
