# Generated by Django 2.2.28 on 2024-08-30 14:45

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0023_auto_20240828_1334'),
    ]

    operations = [
        migrations.AlterField(
            model_name='referral',
            name='organization',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='organization_referrals', to='core.Organization'),
        ),
    ]
